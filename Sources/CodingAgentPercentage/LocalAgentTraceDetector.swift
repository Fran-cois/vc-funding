import Foundation

struct LocalAgentTraceDetector: Sendable {
    private let homeDirectory: URL
    private let applicationsDirectory: URL
    private let environment: [String: String]

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.applicationsDirectory = applicationsDirectory
        self.environment = environment
    }

    func detectedAgents() -> [CodingAgent] {
        CodingAgent.allCases.filter(hasTrace)
    }

    private func hasTrace(for agent: CodingAgent) -> Bool {
        traceLocations(for: agent).contains {
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
        }
    }
}
