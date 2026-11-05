import Foundation

/// Die Bereiche der App, die über das Seitenmenü erreichbar sind.
enum AppDestination: String, CaseIterable, Identifiable {
    case home
    case pastReports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Startseite"
        case .pastReports: "Vergangene Berichte"
        case .settings: "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .pastReports: "doc.text.magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}
