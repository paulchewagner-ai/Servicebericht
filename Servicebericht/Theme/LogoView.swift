import SwiftUI
import UIKit

/// Zeigt das Firmenlogo, sobald ein Bild mit dem Namen „Logo“ in Assets.xcassets liegt.
/// Bis dahin erscheint ein gestrichelter Platzhalter. Das Logo wird nicht nachgezeichnet.
struct LogoView: View {
    var height: CGFloat = 32

    var body: some View {
        if let image = UIImage(named: "Logo") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityLabel("Firmenlogo")
        } else {
            Text("LOGO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.onPrimary.opacity(0.8))
                .frame(width: height * 3.5, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.onPrimary.opacity(0.6),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .accessibilityLabel("Platzhalter für das Firmenlogo")
        }
    }
}

#Preview {
    LogoView()
        .padding()
        .background(Theme.primary)
}
