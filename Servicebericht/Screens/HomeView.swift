import SwiftData
import SwiftUI

/// Startseite mit dem großen Knopf für den Sprachbericht.
struct HomeView: View {
    let onOpenPastReports: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppInfo.StorageKey.technicianName) private var technicianName = ""
    @Query(filter: #Predicate<ServiceReport> { $0.statusRaw == "draft" },
           sort: \ServiceReport.updatedAt, order: .reverse)
    private var drafts: [ServiceReport]

    @State private var activeDialog: VoiceDialogController?
    @State private var showMissingName = false
    @State private var showDraftChoice = false

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var iconCircle: CGFloat = 112

    private var openDraft: ServiceReport? { drafts.first }

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
        .alert("Wie heißt du?", isPresented: $showMissingName) {
            Button("Zu den Einstellungen") { onOpenSettings() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Trag bitte zuerst deinen Namen in den Einstellungen ein. Er erscheint in jedem Bericht.")
        }
        .confirmationDialog("Es gibt einen offenen Entwurf.",
                            isPresented: $showDraftChoice,
                            titleVisibility: .visible) {
            Button("Entwurf fortsetzen") {
                if let openDraft { present(openDraft) }
            }
            Button("Entwurf verwerfen und neu beginnen", role: .destructive) {
                discardDraftsAndStartNew()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            if let openDraft {
                Text(draftDescription(openDraft))
            }
        }
        .fullScreenCover(item: $activeDialog) { controller in
            VoiceDialogView(controller: controller)
        }
    }

    // MARK: - Knöpfe

    private var startButton: some View {
        Button(action: startTapped) {
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

    @ViewBuilder
    private var secondaryButton: some View {
        if let openDraft {
            VStack(spacing: 8) {
                outlinedButton("Entwurf fortsetzen", systemImage: "play.circle.fill") {
                    startDialog(for: openDraft)
                }
                Text(draftDescription(openDraft))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            outlinedButton("Vergangene Berichte ansehen",
                           systemImage: "doc.text.magnifyingglass",
                           action: onOpenPastReports)
        }
    }

    private func outlinedButton(_ title: String,
                                systemImage: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
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

    // MARK: - Ablauf

    private var hasTechnicianName: Bool {
        !technicianName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func startTapped() {
        guard hasTechnicianName else {
            showMissingName = true
            return
        }
        if openDraft != nil {
            showDraftChoice = true
        } else {
            startNewReport()
        }
    }

    private func startDialog(for draft: ServiceReport) {
        guard hasTechnicianName else {
            showMissingName = true
            return
        }
        present(draft)
    }

    private func startNewReport() {
        let report = ServiceReport(technicianName: technicianName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(report)
        try? modelContext.save()
        present(report)
    }

    private func discardDraftsAndStartNew() {
        for draft in drafts {
            modelContext.delete(draft)
        }
        try? modelContext.save()
        startNewReport()
    }

    private func present(_ report: ServiceReport) {
        activeDialog = VoiceDialogController(report: report, context: modelContext)
    }

    private func draftDescription(_ draft: ServiceReport) -> String {
        let date = draft.updatedAt.formatted(.dateTime.day().month(.twoDigits).year().hour().minute()
            .locale(Locale(identifier: "de_DE")))
        let answered = draft.answers.filter(\.hasContent).count
        return "Zuletzt bearbeitet am \(date), \(answered) von \(Questionnaire.questions.count) Fragen beantwortet."
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
        .modelContainer(for: [ServiceReport.self, ReportAnswer.self], inMemory: true)
}
