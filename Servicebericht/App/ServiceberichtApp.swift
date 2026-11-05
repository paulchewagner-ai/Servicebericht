import SwiftData
import SwiftUI

@main
struct ServiceberichtApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Alle Daten bleiben lokal auf dem Gerät (Dateischutz von iPadOS aktiv).
        .modelContainer(for: [ServiceReport.self, ReportAnswer.self])
    }
}
