import SwiftUI

@main
struct VCFundingApp: App {
    @StateObject private var store: UsageStore
    private let scheduler = RefreshScheduler()

    init() {
        _store = StateObject(wrappedValue: UsageStore(providers: [
            CodexUsageProvider(),
            UnavailableAgentUsageProvider(agentName: CodingAgent.claudeCode.rawValue)
        ]))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.shouldSwitch ? "exclamationmark.triangle.fill" : "terminal")
                if let snapshot = store.snapshot(for: .codex) {
                    if let fiveHour = snapshot.fiveHour {
                        usageLabel("5h", window: fiveHour)
                    }
                    if snapshot.fiveHour != nil, snapshot.weekly != nil {
                        Text("·").foregroundStyle(.secondary)
                    }
                    if let weekly = snapshot.weekly {
                        usageLabel("7d", window: weekly)
                    }
                }
            }
            .onAppear { scheduler.start { await store.refresh() } }
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView() }
    }

    private func usageLabel(_ label: String, window: UsageWindow) -> some View {
        HStack(spacing: 2) {
            Text(label)
            Text("\(window.roundedPercent)%")
                .fontWeight(.semibold)
                .foregroundStyle(usageColor(window.usedPercent))
                .monospacedDigit()
        }
    }

    private func usageColor(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .green
    }
}
