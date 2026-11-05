import SwiftUI

/// Einstellungen: Name des Technikers und App-Informationen.
struct SettingsView: View {
    @AppStorage(AppInfo.StorageKey.technicianName) private var technicianName = ""

    var body: some View {
        PageScaffold(title: "Einstellungen") {
            card {
                Text("Dein Name")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                TextField("Vor- und Nachname", text: $technicianName)
                    .font(.title3)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    )
                Text("Wird in jeden Bericht als Techniker übernommen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            card {
                Text("Über die App")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(AppInfo.versionText)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
        .background(Theme.background)
}
