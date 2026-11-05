import Foundation
import SwiftData

/// Bearbeitungsstand eines Berichts.
enum ReportStatus: String, CaseIterable, Codable {
    /// Sprachdialog noch nicht abgeschlossen.
    case draft
    /// Gespeichert, wartet auf die Ausformulierung durch Claude (Etappe 3).
    case pending
    /// Ausformuliert und fertig.
    case completed
    /// Ausformulierung fehlgeschlagen.
    case failed

    var title: String {
        switch self {
        case .draft: "Entwurf"
        case .pending: "Wartet auf Ausformulierung"
        case .completed: "Fertig"
        case .failed: "Fehler"
        }
    }
}

/// Ein Servicebericht. Enthält die Rohantworten aus dem Sprachdialog.
@Model
final class ServiceReport {
    @Attribute(.unique) var id: UUID
    /// Wird erst beim Speichern vergeben: `SB-JJJJMMTT-XXXX`.
    var reportNumber: String?
    var statusRaw: String
    /// Einsatzdatum (Tag, an dem der Dialog begonnen wurde).
    var serviceDate: Date
    var technicianName: String
    /// Index der Frage, an der der Dialog fortgesetzt wird (0 … Anzahl Fragen).
    var currentQuestionIndex: Int
    var createdAt: Date
    var updatedAt: Date
    /// Erfassungszeitpunkt: Moment, in dem der Techniker „speichern“ bestätigt hat.
    var savedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ReportAnswer.report)
    var answers: [ReportAnswer] = []

    init(technicianName: String, now: Date = .now) {
        self.id = UUID()
        self.reportNumber = nil
        self.statusRaw = ReportStatus.draft.rawValue
        self.serviceDate = now
        self.technicianName = technicianName
        self.currentQuestionIndex = 0
        self.createdAt = now
        self.updatedAt = now
        self.savedAt = nil
    }

    var status: ReportStatus {
        get { ReportStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    func answer(for questionNumber: Int) -> ReportAnswer? {
        answers.first { $0.questionNumber == questionNumber }
    }
}

/// Rohantwort auf eine der Standardfragen – unverändert, wie erkannt.
@Model
final class ReportAnswer {
    var questionNumber: Int
    var transcript: String
    /// Frage wurde übersprungen („weiter“ / „nichts“ oder nicht verstanden).
    var skipped: Bool
    var updatedAt: Date
    var report: ServiceReport?

    init(questionNumber: Int, transcript: String, skipped: Bool, now: Date = .now) {
        self.questionNumber = questionNumber
        self.transcript = transcript
        self.skipped = skipped
        self.updatedAt = now
    }

    var hasContent: Bool {
        !skipped && !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
