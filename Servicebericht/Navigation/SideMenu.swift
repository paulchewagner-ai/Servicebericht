import SwiftUI

/// Seitlich einfahrendes Menü mit allen Bereichen und der App-Version.
struct SideMenu: View {
    let selection: AppDestination
    let onSelect: (AppDestination) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Theme.accent)
                .frame(height: Theme.Metrics.accentLineHeight)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                ForEach(AppDestination.allCases) { item in
                    row(for: item)
                }
            }
            .padding(16)

            Spacer(minLength: 0)

            Text(AppInfo.versionText)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(24)
        }
        .frame(width: Theme.Metrics.sideMenuWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.surface.ignoresSafeArea())
        .shadow(color: .black.opacity(0.25), radius: 16, x: 4)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var header: some View {
        HStack {
            Text("Menü")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.onPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Theme.onPrimary)
            .accessibilityLabel("Menü schließen")
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(Theme.primary.ignoresSafeArea(edges: .top))
    }

    private func row(for item: AppDestination) -> some View {
        let isSelected = item == selection
        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: item.systemImage)
                    .font(.title2)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 64)
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SideMenu(selection: .home, onSelect: { _ in }, onClose: {})
}
