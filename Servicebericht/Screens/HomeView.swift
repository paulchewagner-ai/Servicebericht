import SwiftUI

/// Startseite mit dem großen Knopf für den Sprachbericht.
struct HomeView: View {
    let onOpenPastReports: () -> Void
    let onOpenSettings: () -> Void

    @AppStorage(AppInfo.StorageKey.technicianName) private var technicianName = ""
    @State private var showStageHint = false
    @State private var showMissingName = false

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var iconCircle: CGFloat = 112

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    Text("Einsatz beendet?")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    startButton

                    Label("Nur im stehenden Fahrzeug benutzen.", systemImage: "car.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.textSecondary)

                    secondaryButton
                }
                .padding(32)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .alert("Sprachdialog folgt", isPresented: $showStageHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Der Sprachdialog wird in Etappe 2 umgesetzt.")
        }
        .alert("Wie heißt du?", isPresented: $showMissingName) {
            Button("Zu den Einstellungen") { onOpenSettings() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Trag bitte zuerst deinen Namen in den Einstellungen ein. Er erscheint in jedem Bericht.")
        }
    }

    private var startButton: some View {
        Button {
            if technicianName.trimmingCharacters(in: .whitespaces).isEmpty {
                showMissingName = true
            } else {
                showStageHint = true
            }
        } label: {
            HStack(spacing: 28) {
                Image(systemName: "mic.fill")
                    .font(.system(size: iconCircle * 0.45, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: iconCircle, height: iconCircle)
                    .background(Circle().fill(Theme.primary))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sprachbericht starten")
                        .font(.system(size: titleSize, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("Geführter Sprachdialog zum Einsatz")
                        .font(.title3.weight(.medium))
                }
                .foregroundStyle(Theme.onAccent)

                Spacer(minLength: 0)
            }
            .padding(32)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.startButtonHeight)
        }
        .buttonStyle(StartButtonStyle())
        .frame(maxWidth: Theme.Metrics.startButtonWidth)
        .accessibilityHint("Startet die geführte Befragung per Sprache.")
    }

    private var secondaryButton: some View {
        Button(action: onOpenPastReports) {
            Label("Vergangene Berichte ansehen", systemImage: "doc.text.magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 28)
                .frame(minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.textPrimary.opacity(0.35), lineWidth: 2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Großer Cyan-Knopf mit Druckrückmeldung.
private struct StartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        configuration.label
            .background(shape.fill(Theme.accent))
            .overlay(shape.fill(Color.black.opacity(configuration.isPressed ? 0.12 : 0)))
            .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    HomeView(onOpenPastReports: {}, onOpenSettings: {})
        .background(Theme.background)
}
