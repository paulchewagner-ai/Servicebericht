import AVFoundation

/// Liest Texte auf Deutsch vor (offline) und wartet, bis der Text zu Ende gesprochen ist.
@MainActor
final class SpeechSynthesizer: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var currentUtteranceID: ObjectIdentifier?
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestGermanVoice()

    override init() {
        super.init()
        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = true
    }

    /// Spricht den Text und kehrt zurück, sobald er fertig gesprochen oder abgebrochen wurde.
    func speak(_ text: String) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.2
        currentUtteranceID = ObjectIdentifier(utterance)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentUtteranceID = nil
        resumeIfNeeded()
    }

    fileprivate func utteranceEnded(_ id: ObjectIdentifier) {
        // Rückmeldungen zu älteren, bereits abgebrochenen Texten ignorieren.
        guard id == currentUtteranceID else { return }
        currentUtteranceID = nil
        resumeIfNeeded()
    }

    private func resumeIfNeeded() {
        continuation?.resume()
        continuation = nil
    }

    /// Beste installierte deutsche Stimme (Premium > Erweitert > Standard).
    private static func bestGermanVoice() -> AVSpeechSynthesisVoice? {
        let german = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "de-DE" }
        return german.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "de-DE")
    }
}

extension SpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }
}
