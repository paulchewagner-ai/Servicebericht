import Foundation

/// Allgemeine Angaben zur App und gemeinsam genutzte Speicherschlüssel.
enum AppInfo {
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(version) (\(build))"
    }

    enum StorageKey {
        /// Name des Technikers, wird in jeden Bericht übernommen.
        static let technicianName = "technicianName"
    }
}
