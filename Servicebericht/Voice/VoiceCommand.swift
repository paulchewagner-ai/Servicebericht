import Foundation

/// Sprachbefehle im Dialog. Ein Befehl zählt nur, wenn die ganze Äußerung daraus besteht –
/// „zurück“ mitten in einem Satz ist also eine normale Antwort.
enum VoiceCommand: Equatable {
    case repeatQuestion
    case back
    case skip
    case cancel

    static func parse(_ text: String) -> VoiceCommand? {
        let phrase = SpokenText.normalize(text)
        guard !phrase.isEmpty else { return nil }
        if repeatPhrases.contains(phrase) { return .repeatQuestion }
        if backPhrases.contains(phrase) { return .back }
        if skipPhrases.contains(phrase) { return .skip }
        if cancelPhrases.contains(phrase) { return .cancel }
        return nil
    }

    private static let repeatPhrases: Set<String> = [
        "wiederholen", "wiederhole", "bitte wiederholen", "wiederholen bitte",
        "noch mal", "nochmal", "noch einmal", "wie bitte",
    ]
    private static let backPhrases: Set<String> = [
        "zurück", "zurück bitte", "eine frage zurück", "vorherige frage",
    ]
    private static let skipPhrases: Set<String> = [
        "weiter", "nichts", "überspringen", "frage überspringen", "nächste frage",
    ]
    private static let cancelPhrases: Set<String> = [
        "abbrechen", "abbruch", "stopp", "stop", "beenden",
    ]
}

/// Antwort auf „Soll ich den Bericht speichern?“.
enum ConfirmationReply: Equatable {
    case yes
    case no

    static func parse(_ text: String) -> ConfirmationReply? {
        let phrase = SpokenText.normalize(text)
        if yesPhrases.contains(phrase) { return .yes }
        if noPhrases.contains(phrase) { return .no }
        return nil
    }

    private static let yesPhrases: Set<String> = [
        "ja", "ja bitte", "jawohl", "genau", "speichern", "bitte speichern",
        "ja speichern", "ja bitte speichern", "okay", "ok", "passt",
    ]
    private static let noPhrases: Set<String> = [
        "nein", "nee", "nein danke", "nicht speichern", "nein nicht speichern",
    ]
}

enum SpokenText {
    /// Kleinschreibung, Satzzeichen entfernen, Leerraum vereinheitlichen.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) }
        return String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
