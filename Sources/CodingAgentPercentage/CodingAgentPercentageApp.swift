import SwiftUI

@main
struct VCFundingApp: App {
    @StateObject private var store: UsageStore
    private let scheduler = RefreshScheduler()

    init() {
        _store = StateObject(wrappedValue: UsageStore(providers: [
            CodexUsageProvider(),
            UnavailableAgentUsageProvider(agentName: CodingAgent.claudeCode.rawValue)
        ], notifier: SwitchNotificationManager()))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "terminal")
                if let snapshot = store.snapshot(for: .codex) {
                    Text(statusIndicator(snapshot))
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

    }

    private func usageLabel(_ label: String, window: UsageWindow) -> some View {
        HStack(spacing: 2) {
            Text(label)
            Text("\(window.roundedPercent)%")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private func usageColor(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .green
    }

    private func statusIndicator(_ snapshot: UsageSnapshot) -> String {
        let maximum = [snapshot.fiveHour, snapshot.weekly]
            .compactMap { $0?.usedPercent }
            .max() ?? 0
        if maximum >= 90 { return "🔴" }
        if store.shouldBurnTokens { return "🔥" }
        if maximum >= 70 { return "🟠" }
        return "🟢"
    }
}
