import SwiftUI

@main
struct VCFundingApp: App {
    @StateObject private var store: UsageStore
    private let scheduler = RefreshScheduler()

    init() {
        _store = StateObject(wrappedValue: UsageStore(provider: CodexUsageProvider()))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "terminal")
                Text(store.menuBarTitle)
                    .monospacedDigit()
            }
            .onAppear { scheduler.start { await store.refresh() } }
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView() }
    }
}
