import Foundation

/// Off-by-default manual override that skips the live `codex` CLI call and forces Codex usage back
/// to local session-log parsing only, for users who don't want vc-funding to run `codex` at all.
@MainActor
final class CodexOfflineModeSettings: ObservableObject {
    nonisolated static let enabledKey = "CodexOfflineModeEnabled"

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }
}
