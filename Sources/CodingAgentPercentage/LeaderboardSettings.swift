import Foundation

/// Off-by-default opt-in: nothing is submitted anywhere until the user turns this on and taps share.
@MainActor
final class LeaderboardSettings: ObservableObject {
    nonisolated static let enabledKey = "LeaderboardSharingEnabled"
    nonisolated static let handleKey = "LeaderboardHandle"

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    @Published var handle: String {
        didSet { defaults.set(handle, forKey: Self.handleKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        handle = defaults.string(forKey: Self.handleKey) ?? ""
    }
}

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published private(set) var standings: LeaderboardStandings?
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSharedAt: Date?

    private let client: LeaderboardClient

    init(client: LeaderboardClient = LeaderboardClient()) {
        self.client = client
    }

    func refreshStandings() async {
        do {
            standings = try await client.fetchStandings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func share(handle: String, maxedCounts: [String: Int], costsUSD: [String: Double]) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.submit(handle: handle, maxedCounts: maxedCounts, costsUSD: costsUSD)
            errorMessage = nil
            lastSharedAt = Date()
            await refreshStandings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
