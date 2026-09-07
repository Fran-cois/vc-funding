import Foundation

struct LocalAgentTraceDetector: Sendable {
    private let homeDirectory: URL
    private let applicationsDirectory: URL
    private let environment: [String: String]
    private let hasOpenRouterAPIKey: @Sendable () -> Bool

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        hasOpenRouterAPIKey: @escaping @Sendable () -> Bool = { OpenRouterSettings.hasStoredAPIKey() }
    ) {
        self.homeDirectory = homeDirectory
        self.applicationsDirectory = applicationsDirectory
        self.environment = environment
        self.hasOpenRouterAPIKey = hasOpenRouterAPIKey
    }

    func detectedAgents() -> [CodingAgent] {
        CodingAgent.allCases.filter(hasTrace)
    }

    private func hasTrace(for agent: CodingAgent) -> Bool {
        if agent == .openRouter {
            return hasOpenRouterAPIKey()
        }
        return traceLocations(for: agent).contains {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private func traceLocations(for agent: CodingAgent) -> [URL] {
        switch agent {
        case .codex:
            let codexHome = environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
                ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
            return [codexHome.appendingPathComponent("sessions", isDirectory: true)]
        case .claudeCode:
            return [
                homeDirectory.appendingPathComponent(".claude", isDirectory: true),
                homeDirectory.appendingPathComponent("Library/Application Support/Claude", isDirectory: true)
            ]
        case .antigravity:
            return [
                homeDirectory.appendingPathComponent(".gemini/antigravity", isDirectory: true),
                homeDirectory.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true),
                homeDirectory.appendingPathComponent("Library/Application Support/Antigravity", isDirectory: true),
                applicationsDirectory.appendingPathComponent("Antigravity.app", isDirectory: true)
            ]
        case .githubCopilot:
            return [
                homeDirectory.appendingPathComponent(".config/github-copilot", isDirectory: true),
                homeDirectory.appendingPathComponent(
                    "Library/Application Support/Code/User/globalStorage/github.copilot-chat", isDirectory: true
                ),
                homeDirectory.appendingPathComponent(
                    "Library/Application Support/Code/User/globalStorage/github.copilot", isDirectory: true
                )
            ]
        case .openRouter:
            // Detected via a stored Keychain API key instead, see hasTrace(for:).
            return []
        }
    }
}
