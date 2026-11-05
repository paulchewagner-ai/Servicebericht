import Foundation
import Observation
import OSLog
import SwiftData
import UIKit

/// Einstellbare Werte für den Sprachdialog.
enum DialogSettings {
    /// So lange wird auf den Beginn einer Antwort gewartet.
    static let initialTimeout: Duration = .seconds(10)
    /// Pause nach dem Sprechen, die eine Antwort beendet.
    static let silenceTimeout: Duration = .seconds(3)
    /// Obergrenze für eine einzelne Antwort.
    static let maxAnswerDuration: Duration = .seconds(180)
    /// So oft wird nach einer leeren Antwort nachgefragt, bevor die Frage übersprungen wird.
    static let maxNotUnderstoodRetries = 2
    /// So oft wird bei „Soll ich speichern?“ nachgefragt.
    static let maxConfirmationAttempts = 3
}

/// Steuert den geführten Sprachdialog: Fragen vorlesen, Antworten erkennen,
/// Sprachbefehle auswerten, Entwurf nach jeder Antwort sichern.
@MainActor
@Observable
final class VoiceDialogController: Identifiable {
    enum Activity: Equatable {
        case preparing
        case speaking
        case listening
        case finished(Outcome)
        case failed(Failure)
    }

    enum Outcome: Equatable {
        case saved
        case keptAsDraft
        case cancelled
    }

    struct Failure: Equatable {
        let message: String
        let offersSettings: Bool
    }

    private enum DialogExit: Error {
        case cancelledByVoice
    }

    private(set) var activity: Activity = .preparing
    private(set) var currentIndex: Int
    private(set) var isConfirming = false
    /// Was die App gerade sagt bzw. zuletzt gesagt hat.
    private(set) var spokenText = ""
    /// Live erkannter Text der laufenden Antwort.
    private(set) var liveTranscript = ""
    /// Nur Debug-Build: Grund, warum Antworten getippt statt gesprochen werden.
    private(set) var typingFallbackReason: String?

    let questions = Questionnaire.questions
    let report: ServiceReport

    private let context: ModelContext
    private let speaker = SpeechSynthesizer()
    private let listener = SpeechRecognizer()
    @ObservationIgnored private var runTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "Servicebericht", category: "VoiceDialog")

    nonisolated var id: UUID { reportID }
    private nonisolated let reportID: UUID

    init(report: ServiceReport, context: ModelContext) {
        self.report = report
        self.context = context
        self.reportID = report.id
        self.currentIndex = min(max(report.currentQuestionIndex, 0), Questionnaire.questions.count)
    }

    var currentQuestion: Question? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    func isAnswered(_ question: Question) -> Bool {
        report.answer(for: question.number)?.hasContent == true
    }

    // MARK: - Steuerung von außen

    func start() {
        guard runTask == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        listener.onTranscriptChange = { [weak self] text in
            self?.liveTranscript = text
        }
        listener.onTypingFallback = { [weak self] reason in
            self?.typingFallbackReason = reason
        }
        runTask = Task { [weak self] in
            await self?.run()
        }
    }

    /// Hält alles sofort an. Der Entwurf ist bereits gesichert.
    func stop() {
        runTask?.cancel()
        runTask = nil
        speaker.stop()
        listener.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        AudioSessionController.deactivate()
    }

    /// Text so behandeln, als wäre er gesprochen worden (Befehlsknöpfe, Debug-Eingabe).
    func submit(_ text: String) {
        guard listener.isListening else { return }
        listener.inject(text)
    }

    // MARK: - Ablauf

    private func run() async {
        activity = .preparing
        let permissionsGranted = await SpeechRecognizer.requestPermissions()
        if !permissionsGranted {
            #if DEBUG
            listener.enableTypingFallback(reason: "Mikrofon oder Spracherkennung nicht erlaubt.")
            #else
            activity = .failed(Failure(
                message: "Für den Sprachbericht braucht die App Zugriff auf Mikrofon und Spracherkennung. Bitte erlaube beides in den Einstellungen.",
                offersSettings: true))
            return
            #endif
        }

        do {
            do {
                try AudioSessionController.activateForDialog()
            } catch {
                #if DEBUG
                listener.enableTypingFallback(reason: "Audio-Sitzung: \(SpeechRecognizer.describe(error))")
                #else
                throw error
                #endif
            }
            await say(introText())
            while true {
                try await askQuestions()
                if let outcome = try await confirmAndSave() {
                    activity = .finished(outcome)
                    break
                }
            }
        } catch is CancellationError {
            // Abbruch über den Knopf – nichts mehr sagen.
        } catch DialogExit.cancelledByVoice {
            await say("Abgebrochen. Dein Entwurf bleibt gespeichert.")
            activity = .finished(.cancelled)
        } catch {
            logger.error("Sprachdialog fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            activity = .failed(Failure(message: SpeechRecognizer.describe(error), offersSettings: false))
        }

        UIApplication.shared.isIdleTimerDisabled = false
        AudioSessionController.deactivate()
    }

    private func introText() -> String {
        let firstName = report.technicianName.split(separator: " ").first.map(String.init) ?? ""
        let greeting = firstName.isEmpty ? "Hallo." : "Hallo \(firstName)."
        if report.answers.isEmpty {
            return "\(greeting) Ich stelle dir jetzt \(questions.count) Fragen zu deinem Einsatz. "
                + "Bitte nur im stehenden Fahrzeug. Antworte frei und mach am Ende eine kurze Pause. "
                + "Du kannst jederzeit „wiederholen“, „zurück“, „weiter“ oder „abbrechen“ sagen."
        }
        let next = min(currentIndex + 1, questions.count)
        return "\(greeting) Wir machen mit deinem Entwurf weiter, bei Frage \(next)."
    }

    private func askQuestions() async throws {
        isConfirming = false
        var shouldReadQuestion = true
        var notUnderstood = 0

        while currentIndex < questions.count {
            try Task.checkCancellation()
            let question = questions[currentIndex]

            if shouldReadQuestion {
                await say(questionText(for: question))
            }
            shouldReadQuestion = true

            let heard = try await listen()

            if let command = VoiceCommand.parse(heard) {
                notUnderstood = 0
                switch command {
                case .repeatQuestion:
                    break
                case .back:
                    if currentIndex == 0 {
                        await say("Das ist schon die erste Frage.")
                    } else {
                        move(to: currentIndex - 1)
                    }
                case .skip:
                    markSkippedIfUnanswered(question)
                    move(to: currentIndex + 1)
                case .cancel:
                    throw DialogExit.cancelledByVoice
                }
                continue
            }

            if heard.isEmpty {
                notUnderstood += 1
                if notUnderstood <= DialogSettings.maxNotUnderstoodRetries {
                    await say("Ich habe dich nicht verstanden. Bitte wiederhole deine Antwort.")
                    shouldReadQuestion = false
                } else {
                    await say("Ich überspringe die Frage erst einmal.")
                    markSkippedIfUnanswered(question)
                    move(to: currentIndex + 1)
                    notUnderstood = 0
                }
                continue
            }

            store(heard, for: question)
            notUnderstood = 0
            move(to: currentIndex + 1)
            if currentIndex < questions.count {
                await say("Danke.")
            }
        }
    }

    private func questionText(for question: Question) -> String {
        var text = "Frage \(question.number) von \(questions.count). \(question.prompt)"
        if let previous = report.answer(for: question.number), previous.hasContent {
            text += " Bisher hast du gesagt: \(previous.transcript). "
                + "Sag eine neue Antwort, oder „weiter“, um sie zu behalten."
        }
        return text
    }

    /// Liefert `nil`, wenn der Techniker zurück zu den Fragen möchte.
    private func confirmAndSave() async throws -> Outcome? {
        isConfirming = true
        guard questions.contains(where: isAnswered) else {
            await say("Du hast noch keine Frage beantwortet. Der Bericht bleibt als Entwurf gespeichert.")
            return .keptAsDraft
        }

        var prompt = summaryText() + " Soll ich den Bericht speichern? Sag ja oder nein."
        var attempts = 0

        while true {
            try Task.checkCancellation()
            await say(prompt)
            let heard = try await listen()

            if let command = VoiceCommand.parse(heard) {
                switch command {
                case .repeatQuestion:
                    prompt = summaryText() + " Soll ich den Bericht speichern? Sag ja oder nein."
                    continue
                case .back:
                    move(to: questions.count - 1)
                    return nil
                case .cancel:
                    throw DialogExit.cancelledByVoice
                case .skip:
                    break // wie eine unklare Antwort behandeln
                }
            }

            switch ConfirmationReply.parse(heard) {
            case .yes:
                try saveReport()
                await say("Der Bericht ist gespeichert. Danke!")
                return .saved
            case .no:
                await say("In Ordnung. Der Bericht bleibt als Entwurf gespeichert. Du kannst ihn später auf der Startseite fortsetzen.")
                return .keptAsDraft
            case nil:
                attempts += 1
                if attempts >= DialogSettings.maxConfirmationAttempts {
                    await say("Ich habe keine eindeutige Antwort verstanden. Der Bericht bleibt als Entwurf gespeichert.")
                    return .keptAsDraft
                }
                prompt = "Bitte sag ja oder nein. Soll ich den Bericht speichern?"
            }
        }
    }

    private func summaryText() -> String {
        let open = questions.filter { !isAnswered($0) }.map(\.number)
        let answeredCount = questions.count - open.count
        var text = "Du hast \(answeredCount) von \(questions.count) Fragen beantwortet."
        if open.count == 1 {
            text += " Offen ist Frage \(open[0])."
        } else if open.count > 1 {
            text += " Offen sind die Fragen \(Self.joinedList(open))."
        }
        return text
    }

    /// „2, 4 und 6“
    static func joinedList(_ numbers: [Int]) -> String {
        let words = numbers.map(String.init)
        guard let last = words.last else { return "" }
        guard words.count > 1 else { return last }
        return words.dropLast().joined(separator: ", ") + " und " + last
    }

    // MARK: - Sprechen und Hören

    private func say(_ text: String) async {
        guard !Task.isCancelled else { return }
        spokenText = text
        activity = .speaking
        await speaker.speak(text)
    }

    private func listen() async throws -> String {
        try Task.checkCancellation()
        liveTranscript = ""
        activity = .listening
        let text = try await listener.listen(initialTimeout: DialogSettings.initialTimeout,
                                             silenceTimeout: DialogSettings.silenceTimeout,
                                             maxDuration: DialogSettings.maxAnswerDuration)
        try Task.checkCancellation()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Speichern

    private func store(_ transcript: String, for question: Question) {
        let now = Date.now
        if let existing = report.answer(for: question.number) {
            existing.transcript = transcript
            existing.skipped = false
            existing.updatedAt = now
        } else {
            report.answers.append(ReportAnswer(questionNumber: question.number,
                                               transcript: transcript,
                                               skipped: false,
                                               now: now))
        }
        report.updatedAt = now
        persist()
    }

    /// Eine bestehende Antwort bleibt erhalten, wenn der Techniker „weiter“ sagt.
    private func markSkippedIfUnanswered(_ question: Question) {
        guard report.answer(for: question.number)?.hasContent != true else { return }
        if let existing = report.answer(for: question.number) {
            existing.skipped = true
            existing.updatedAt = .now
        } else {
            report.answers.append(ReportAnswer(questionNumber: question.number,
                                               transcript: "",
                                               skipped: true))
        }
        report.updatedAt = .now
        persist()
    }

    private func move(to index: Int) {
        currentIndex = min(max(index, 0), questions.count)
        report.currentQuestionIndex = currentIndex
        report.updatedAt = .now
        persist()
    }

    private func saveReport() throws {
        let existingNumbers = try context.fetch(FetchDescriptor<ServiceReport>())
            .compactMap(\.reportNumber)
        let now = Date.now
        report.reportNumber = ReportNumberGenerator.make(for: report.serviceDate,
                                                         existing: Set(existingNumbers))
        report.status = .pending
        report.savedAt = now
        report.updatedAt = now
        try context.save()
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            logger.error("Entwurf konnte nicht gesichert werden: \(error.localizedDescription, privacy: .public)")
        }
    }
}
