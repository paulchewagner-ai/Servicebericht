import AVFoundation
import Speech

enum SpeechRecognizerError: LocalizedError {
    case recognizerUnavailable
    case audioInputUnavailable
    case recognitionFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "Die deutsche Spracherkennung ist gerade nicht verfügbar. Prüf bitte, ob Diktieren auf dem iPad eingeschaltet ist (Einstellungen › Allgemein › Tastatur › Diktierfunktion)."
        case .audioInputUnavailable:
            "Es wurde kein Mikrofon gefunden. Im Simulator: Mac-Systemeinstellungen › Datenschutz & Sicherheit › Mikrofon › Simulator erlauben."
        case .recognitionFailed(let details):
            "Die Spracherkennung ist mehrfach fehlgeschlagen (\(details))."
        }
    }
}

/// Thread-sichere Ablage der aktuellen Erkennungsanfrage. Der Audio-Tap läuft auf einem
/// eigenen Audio-Thread und darf nicht auf den Main Actor zugreifen.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ newRequest: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        request = newRequest
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}

/// Hört eine Antwort ab und liefert den erkannten Text.
/// Die Antwort gilt als beendet, wenn der Techniker eine Pause macht.
@MainActor
final class SpeechRecognizer {
    /// Wird bei jeder Änderung des erkannten Textes aufgerufen (Live-Anzeige).
    var onTranscriptChange: ((String) -> Void)?
    /// Nur Debug-Build: Wird aufgerufen, wenn auf getippte Eingabe umgeschaltet wird.
    var onTypingFallback: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let audioEngine = AVAudioEngine()
    private let requestBox = RequestBox()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?
    private var committedText = ""
    private var partialText = ""
    private var silenceTimeout: Duration = .seconds(3)
    private var consecutiveFailures = 0
    private var lastErrorDescription = ""
    /// Erst auf dem Gerät erkennen; schlägt das fehl, auf Apples Server ausweichen (braucht Netz).
    private var preferOnDevice = true
    /// Nur Debug-Build: Erkennung nicht nutzbar, Antworten werden getippt.
    private(set) var isTypingFallback = false
    /// Zähler, um Rückmeldungen alter Erkennungsaufgaben zu ignorieren.
    private var generation = 0

    var isListening: Bool { continuation != nil }

    /// Fragt Spracherkennung und Mikrofon an. Liefert `true`, wenn beides erlaubt ist.
    static func requestPermissions() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Hört zu, bis nach dem Sprechen eine Pause von `silenceTimeout` entsteht.
    /// Kommt innerhalb von `initialTimeout` gar nichts, wird ein leerer Text geliefert.
    func listen(initialTimeout: Duration,
                silenceTimeout: Duration,
                maxDuration: Duration) async throws -> String {
        if continuation != nil { cancel() }
        if isTypingFallback {
            return try await waitForTypedInput()
        }
        guard let recognizer, recognizer.isAvailable else {
            return try await fallbackOrThrow(SpeechRecognizerError.recognizerUnavailable)
        }
        self.silenceTimeout = silenceTimeout
        committedText = ""
        partialText = ""
        consecutiveFailures = 0

        do {
            try startAudioEngine()
        } catch {
            stopAudio()
            return try await fallbackOrThrow(error)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            startRecognitionTask(with: recognizer)
            scheduleTimeout(initialTimeout)
            maxDurationTask = Task { [weak self] in
                try? await Task.sleep(for: maxDuration)
                guard let self, !Task.isCancelled else { return }
                self.finish(with: .success(self.fullText))
            }
        }
    }

    /// Bricht das Zuhören ab; `listen` wirft dann `CancellationError`.
    func cancel() {
        finish(with: .failure(CancellationError()))
    }

    /// Beendet das Zuhören mit einem vorgegebenen Text (Befehlsknöpfe, Debug-Eingabe).
    func inject(_ text: String) {
        finish(with: .success(text))
    }

    /// Nur Debug-Build: ab sofort nur getippte Eingaben verwenden.
    func enableTypingFallback(reason: String) {
        #if DEBUG
        isTypingFallback = true
        onTypingFallback?(reason)
        #endif
    }

    // MARK: - Intern

    private var fullText: String {
        [committedText, partialText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func waitForTypedInput() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Im Debug-Build auf getippte Eingabe umschalten, im Release-Build den Fehler melden.
    private func fallbackOrThrow(_ error: Error) async throws -> String {
        #if DEBUG
        enableTypingFallback(reason: Self.describe(error))
        return try await waitForTypedInput()
        #else
        throw error
        #endif
    }

    private func startAudioEngine() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechRecognizerError.audioInputUnavailable
        }
        input.removeTap(onBus: 0)
        Self.installTap(on: input, format: format, box: requestBox)
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func startRecognitionTask(with recognizer: SFSpeechRecognizer) {
        generation += 1
        let currentGeneration = generation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        // Bevorzugt auf dem Gerät erkennen – funktioniert dann auch ohne Netz.
        request.requiresOnDeviceRecognition = preferOnDevice && recognizer.supportsOnDeviceRecognition
        self.request = request
        requestBox.set(request)

        task = Self.makeTask(recognizer: recognizer, request: request) { [weak self] text, isFinal, errorText in
            Task { @MainActor in
                self?.handle(text: text, isFinal: isFinal, errorText: errorText,
                             generation: currentGeneration)
            }
        }
    }

    private func handle(text: String?, isFinal: Bool, errorText: String?, generation resultGeneration: Int) {
        guard resultGeneration == generation, continuation != nil else { return }

        if let text {
            partialText = text
            onTranscriptChange?(fullText)
            if !fullText.isEmpty {
                scheduleTimeout(silenceTimeout)
            }
        }

        let failed = errorText != nil
        guard isFinal || failed else { return }

        // Ein Erkennungsabschnitt ist zu Ende (z. B. Zeitlimit). Text sichern und weiterhören.
        if !partialText.isEmpty {
            committedText = fullText
            partialText = ""
        }

        if let errorText {
            lastErrorDescription = errorText
            consecutiveFailures += 1
            // Erkennung auf dem Gerät klappt nicht (z. B. Sprachpaket fehlt): auf Server ausweichen.
            if request?.requiresOnDeviceRecognition == true, fullText.isEmpty {
                preferOnDevice = false
            }
        } else {
            consecutiveFailures = 0
        }

        if consecutiveFailures >= 3 {
            if !fullText.isEmpty {
                finish(with: .success(fullText))
                return
            }
            #if DEBUG
            // Zuhören beenden, aber auf getippte Eingabe warten statt abzubrechen.
            timeoutTask?.cancel()
            maxDurationTask?.cancel()
            generation += 1
            stopAudio()
            enableTypingFallback(reason: "Spracherkennung fehlgeschlagen: \(lastErrorDescription)")
            #else
            finish(with: .failure(SpeechRecognizerError.recognitionFailed(details: lastErrorDescription)))
            #endif
            return
        }

        task?.cancel()
        request?.endAudio()
        if let recognizer {
            startRecognitionTask(with: recognizer)
        }
    }

    private func scheduleTimeout(_ duration: Duration) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled, !self.isTypingFallback else { return }
            self.finish(with: .success(self.fullText))
        }
    }

    private func finish(with result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        maxDurationTask?.cancel()
        maxDurationTask = nil
        generation += 1
        stopAudio()
        continuation.resume(with: result)
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        requestBox.set(nil)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let text = (error as? LocalizedError)?.errorDescription ?? nsError.localizedDescription
        return "\(text) [\(nsError.domain) \(nsError.code)]"
    }

    // Die folgenden Hilfsfunktionen sind bewusst `nonisolated`: Ihre Closures laufen auf
    // Hintergrund-Threads und dürfen nicht als Main-Actor-Code gelten.

    nonisolated private static func installTap(on node: AVAudioInputNode,
                                               format: AVAudioFormat,
                                               box: RequestBox) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            box.append(buffer)
        }
    }

    nonisolated private static func makeTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, Bool, String?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let nsError = error as NSError?,
               nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
                // „Keine Sprache erkannt“ ist normal bei Stille – kein Fehler, einfach weiterhören.
                onUpdate(result?.bestTranscription.formattedString, true, nil)
                return
            }
            let errorText = error.map { error -> String in
                let nsError = error as NSError
                return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
            }
            onUpdate(result?.bestTranscription.formattedString,
                     result?.isFinal ?? false,
                     errorText)
        }
    }
}
