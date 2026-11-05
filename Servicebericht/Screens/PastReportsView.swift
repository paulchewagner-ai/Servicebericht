import SwiftUI

/// Liste der gespeicherten Berichte. Inhalt folgt in Etappe 4.
struct PastReportsView: View {
    var body: some View {
        PageScaffold(title: "Vergangene Berichte") {
            ContentUnavailableView(
                "Noch keine Berichte",
                systemImage: "doc.text",
                description: Text("Gespeicherte Sprachberichte erscheinen hier.")
            )
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 48)
        }
    }
}

#Preview {
    PastReportsView()
        .background(Theme.background)
}
