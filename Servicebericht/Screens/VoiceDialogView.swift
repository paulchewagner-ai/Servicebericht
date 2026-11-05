import SwiftUI
import UIKit

/// Vollbildansicht während des Sprachdialogs. Bedienung läuft über Sprache;
/// die Knöpfe sind nur Rückfallebene.
struct VoiceDialogView: View {
    let controller: VoiceDialogController

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    #if DEBUG
    @State private var debugInput = ""
    #endif

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle()
                .fill(Theme.accent)
                .frame(height: Theme.Metrics.accentLineHeight)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    progressBar
                    switch controller.activity {
                    case .finished(let outcome):
                        finishedView(outcome)
                    case .failed(let failure):
                        failedView(failure)
                    default:
                        dialogContent
                    }
                }
                .padding(32)
                .frame(maxWidth: Theme.Metrics.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            if isRunning {
                commandBar
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.interactive)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private var isRunning: Bool {
        switch controller.activity {
        case .finished, .failed: false
        default: true
        }
    }

    // MARK: - Kopfleiste

    private var topBar: some View {
        HStack(spacing: 16) {
            Text("Sprachbericht")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.onPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if isRunning {
                Button {
                    controller.stop()
                    dismiss()
                } label: {
                    Label("Abbrechen", systemImage: "xmark")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Theme.onPrimary)
                .accessibilityHint("Beendet den Dialog. Der Entwurf bleibt gespeichert.")
            }
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 64)
        .background(Theme.primary.ignoresSafeArea(edges: .top))
    }

    // MARK: - Fortschritt

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(progressTitle)
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(Array(controller.questions.enumerated()), id: \.element.id) { index, question in
                    Capsule()
                        .fill(segmentColor(index: index, question: question))
                        .overlay(
                            Capsule().strokeBorder(
                                index == controller.currentIndex && !controller.isConfirming
                                    ? Theme.textPrimary : Color.clear,
                                lineWidth: 2)
                        )
                        .frame(height: 12)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var progressTitle: String {
        if controller.isConfirming || controller.currentQuestion == nil {
            return "Abschluss"
        }
        return "Frage \(controller.currentIndex + 1) von \(controller.questions.count)"
    }

    private func segmentColor(index: Int, question: Question) -> Color {
        controller.isAnswered(question) ? Theme.accent : Theme.separator
    }

    // MARK: - Dialog

    private var dialogContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            statusIndicator

            Text(headline)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if controller.activity == .listening || !controller.liveTranscript.isEmpty {
                transcriptBox
            }

            #if DEBUG
            if let reason = controller.typingFallbackReason {
                Label("DEBUG: Sprache nicht nutzbar – bitte Antworten unten eintippen.\n\(reason)",
                      systemImage: "keyboard")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            debugInputField
            #endif
        }
    }

    private var headline: String {
        if controller.isConfirming { return "Soll ich den Bericht speichern?" }
        return controller.currentQuestion?.prompt ?? ""
    }

    private var statusIndicator: some View {
        let isListening = controller.activity == .listening
        let isSpeaking = controller.activity == .speaking
        let symbol: String
        let title: String
        switch controller.activity {
        case .listening:
            symbol = "mic.fill"
            title = "Ich höre zu …"
        case .speaking:
            symbol = "speaker.wave.3.fill"
            title = "Ich spreche …"
        default:
            symbol = "hourglass"
            title = "Einen Moment …"
        }

        return HStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(isListening ? Theme.onAccent : Theme.accent)
                .frame(width: 88, height: 88)
                .background(Circle().fill(isListening ? Theme.accent : Theme.primary))
                .symbolEffect(.pulse, isActive: isListening)
                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var transcriptBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erkannt")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
            Text(controller.liveTranscript.isEmpty ? "…" : controller.liveTranscript)
                .font(.title3)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
    }

    // MARK: - Befehlsleiste

    private var commandBar: some View {
        VStack(spacing: 12) {
            Text("Du kannst auch sagen:")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 16) {
                commandButton("Wiederholen", systemImage: "arrow.counterclockwise")
                commandButton("Zurück", systemImage: "chevron.backward")
                commandButton("Weiter", systemImage: "chevron.forward")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.separator).frame(height: 1)
        }
    }

    private func commandButton(_ title: String, systemImage: String) -> some View {
        Button {
            controller.submit(title)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: 220, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.textPrimary.opacity(0.35), lineWidth: 2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(controller.activity != .listening)
        .opacity(controller.activity == .listening ? 1 : 0.4)
    }

    // MARK: - Ende

    private func finishedView(_ outcome: VoiceDialogController.Outcome) -> some View {
        let symbol: String
        let title: String
        let detail: String
        switch outcome {
        case .saved:
            symbol = "checkmark.circle.fill"
            title = "Bericht gespeichert"
            detail = "Berichtsnummer \(controller.report.reportNumber ?? "–"). Der Bericht wird ausformuliert, sobald Netz verfügbar ist."
        case .keptAsDraft:
            symbol = "tray.full.fill"
            title = "Als Entwurf gespeichert"
            detail = "Du kannst den Entwurf auf der Startseite fortsetzen."
        case .cancelled:
            symbol = "pause.circle.fill"
            title = "Abgebrochen"
            detail = "Dein Entwurf bleibt gespeichert und kann auf der Startseite fortgesetzt werden."
        }
        return VStack(alignment: .leading, spacing: 24) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            primaryButton("Zur Startseite") { dismiss() }
        }
    }

    private func failedView(_ failure: VoiceDialogController.Failure) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Sprachdialog nicht möglich")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(failure.message)
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            if failure.offersSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                primaryButton("Einstellungen öffnen") { openURL(url) }
            }
            Button("Schließen") { dismiss() }
                .font(.title3.weight(.semibold))
                .frame(minHeight: 56)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 40)
                .frame(minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                        .fill(Theme.accent)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debug

    #if DEBUG
    /// Nur im Debug-Build: Antworten tippen statt sprechen (z. B. im Simulator).
    private var debugInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG – Antwort tippen statt sprechen")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            HStack {
                TextField("Antwort oder Befehl", text: $debugInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(sendDebugInput)
                Button("Senden", action: sendDebugInput)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(controller.activity != .listening)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.orange, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
        )
    }

    private func sendDebugInput() {
        controller.submit(debugInput)
        debugInput = ""
    }
    #endif
}
