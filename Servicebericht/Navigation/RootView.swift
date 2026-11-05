import SwiftUI

/// Grundgerüst: Kopfleiste, Akzentlinie, aktueller Bereich und einfahrendes Seitenmenü.
struct RootView: View {
    @State private var destination: AppDestination = .home
    @State private var isMenuOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background.ignoresSafeArea())
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(height: Theme.Metrics.accentLineHeight)
                            .accessibilityHidden(true)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { headerItems }
                    .toolbarBackground(Theme.headerBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    // Sorgt für helle Statusleiste und weiße Symbole auf Dunkelblau.
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .accessibilityHidden(isMenuOpen)

            if isMenuOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeMenu)
                    .accessibilityLabel("Menü schließen")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                    .zIndex(1)

                SideMenu(selection: destination, onSelect: select, onClose: closeMenu)
                    .transition(.move(edge: .leading))
                    .zIndex(2)
            }
        }
        .tint(Theme.interactive)
    }

    @ViewBuilder
    private var content: some View {
        switch destination {
        case .home:
            HomeView(
                onOpenPastReports: { destination = .pastReports },
                onOpenSettings: { destination = .settings }
            )
        case .pastReports:
            PastReportsView()
        case .settings:
            SettingsView()
        }
    }

    @ToolbarContentBuilder
    private var headerItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = true }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2.weight(.semibold))
                        .frame(minWidth: Theme.Metrics.minTapTarget,
                               minHeight: Theme.Metrics.minTapTarget)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Theme.onPrimary)
                .accessibilityLabel("Menü öffnen")

                Text("Servicebericht")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.onPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            LogoView(height: 30)
        }
    }

    private func select(_ newDestination: AppDestination) {
        destination = newDestination
        closeMenu()
    }

    private func closeMenu() {
        withAnimation(.easeOut(duration: 0.25)) { isMenuOpen = false }
    }
}

#Preview {
    RootView()
}
