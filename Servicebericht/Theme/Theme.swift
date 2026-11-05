import SwiftUI
import UIKit

/// Zentrale Ablage aller Farben und Maße.
/// Die CI-Farben sind vorläufig und werden durch die offiziellen MEIKO-Werte ersetzt –
/// dafür nur die beiden Hex-Werte unten ändern.
enum Theme {

    // MARK: - CI-Grundfarben (vorläufig)

    /// Primärfarbe Dunkelblau – Kopfleiste und Text.
    static let ciPrimaryHex: UInt32 = 0x0A2540
    /// Akzentfarbe Cyan – Startknopf und Hervorhebungen.
    static let ciAccentHex: UInt32 = 0x00B3FF

    // MARK: - Feste Farben

    static let primary = Color(uiColor: UIColor(hex: ciPrimaryHex))
    static let accent = Color(uiColor: UIColor(hex: ciAccentHex))

    /// Textfarbe auf Primärfarbe.
    static let onPrimary = Color.white
    /// Textfarbe auf Cyan. Nie Weiß auf Cyan (Kontrast nur ca. 2,4 : 1),
    /// Dunkelblau erreicht ca. 6,6 : 1.
    static let onAccent = primary

    /// Kopfleiste – in beiden Modi Dunkelblau.
    static let headerBackground = primary

    // MARK: - Dynamische Farben (Hell / Dunkel)

    static let background = dynamic(light: 0xF4F7FA, dark: 0x0B121C)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x16212F)
    static let textPrimary = dynamic(light: ciPrimaryHex, dark: 0xF1F4F8)
    static let textSecondary = dynamic(light: 0x4A5D72, dark: 0xA9B6C5)
    static let separator = dynamic(light: 0xD5DDE6, dark: 0x2A3A4E)

    /// Farbe für antippbare Texte und Symbole.
    /// Hell: Dunkelblau (Cyan auf Weiß wäre zu kontrastarm), Dunkel: Cyan.
    static let interactive = dynamic(light: ciPrimaryHex, dark: ciAccentHex)

    // MARK: - Maße

    enum Metrics {
        /// Mindestgröße jeder Tippfläche (Arbeitshandschuhe).
        static let minTapTarget: CGFloat = 44
        /// Größe des Startknopfs auf der Startseite.
        static let startButtonWidth: CGFloat = 560
        static let startButtonHeight: CGFloat = 220
        /// Höhe der Akzentlinie unter der Kopfleiste.
        static let accentLineHeight: CGFloat = 4
        static let cornerRadius: CGFloat = 16
        /// Maximale Inhaltsbreite auf Unterseiten.
        static let contentMaxWidth: CGFloat = 900
        static let sideMenuWidth: CGFloat = 340
    }

    // MARK: - Hilfsfunktionen

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
