import Foundation

/// Die vier Freitextfelder des Berichts.
enum ReportField: String, CaseIterable, Codable {
    case assignmentAndMachine
    case findings
    case workAndMaterial
    case resultAndNextSteps

    var title: String {
        switch self {
        case .assignmentAndMachine: "Einsatz und Maschine"
        case .findings: "Befund"
        case .workAndMaterial: "Arbeiten und Material"
        case .resultAndNextSteps: "Ergebnis und nächste Schritte"
        }
    }
}

struct Question: Identifiable, Hashable {
    let number: Int
    /// Text, der vorgelesen und angezeigt wird.
    let prompt: String
    let field: ReportField

    var id: Int { number }
}

/// Die 7 Standardfragen (freigegeben am 05.11.2026).
enum Questionnaire {
    static let questions: [Question] = [
        Question(number: 1,
                 prompt: "Bei welchem Kunden warst du, und wo steht die Maschine?",
                 field: .assignmentAndMachine),
        Question(number: 2,
                 prompt: "Um welche Maschine ging es? Nenne Hersteller, Bauart, Modell und, wenn zur Hand, die Seriennummer.",
                 field: .assignmentAndMachine),
        Question(number: 3,
                 prompt: "Was war der Anlass des Einsatzes? Zum Beispiel Störung, Wartung oder Inbetriebnahme – und welcher Fehler wurde gemeldet?",
                 field: .findings),
        Question(number: 4,
                 prompt: "Was hast du festgestellt? Nenne die Ursache und auffällige Messwerte, etwa Temperaturen oder Wasserhärte.",
                 field: .findings),
        Question(number: 5,
                 prompt: "Welche Arbeiten hast du durchgeführt?",
                 field: .workAndMaterial),
        Question(number: 6,
                 prompt: "Welche Ersatzteile hast du verbaut? Bitte mit Bezeichnung, Artikelnummer und Menge.",
                 field: .workAndMaterial),
        Question(number: 7,
                 prompt: "In welchem Zustand hast du die Maschine übergeben, und ist ein Folgeeinsatz nötig?",
                 field: .resultAndNextSteps),
    ]
}
