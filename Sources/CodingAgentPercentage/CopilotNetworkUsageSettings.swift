import Foundation

/// Off-by-default opt-in for the only provider that reads local credentials and calls the network.
@MainActor
final class CopilotNetworkUsageSettings: ObservableObject {
    nonisolated static let enabledKey = "GitHubCopilotNetworkUsageEnabled"

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }
}
