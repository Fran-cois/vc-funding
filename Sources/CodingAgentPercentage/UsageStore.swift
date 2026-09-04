import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private let provider: any AgentUsageProvider

    init(provider: any AgentUsageProvider) {
        self.provider = provider
    }

    var menuBarTitle: String {
        guard let snapshot else { return "5h — · 7d —" }
        return "5h \(percent(snapshot.fiveHour)) · 7d \(percent(snapshot.weekly))"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await provider.fetchUsage()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func percent(_ window: UsageWindow?) -> String {
        window.map { "\($0.roundedPercent)%" } ?? "—"
    }
}
