import AVFoundation

/// Richtet die Audio-Sitzung für Sprachausgabe und -erkennung im Wechsel ein.
enum AudioSessionController {
    static func activateForDialog() throws {
        let session = AVAudioSession.sharedInstance()
        // Lautsprecher statt Hörmuschel; Bluetooth erlaubt die Freisprechanlage im Auto.
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])
        try session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
