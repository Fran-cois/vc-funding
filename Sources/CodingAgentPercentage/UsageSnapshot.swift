import Foundation

struct UsageWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var roundedPercent: Int { Int(usedPercent.rounded()) }
}

struct UsageSnapshot: Equatable, Sendable {
    let agentName: String
    let fiveHour: UsageWindow?
    let weekly: UsageWindow?
    let refreshedAt: Date
    let sourceUpdatedAt: Date
}

enum UsageProviderError: LocalizedError, Equatable {
    case sessionsDirectoryMissing
    case noUsageData
    case unsupportedAgent(String)

    var errorDescription: String? {
        switch self {
        case .sessionsDirectoryMissing:
            "Codex session storage was not found. Run Codex and try again."
        case .noUsageData:
            "No current Codex usage snapshot is available yet."
        case .unsupportedAgent(let name):
            "\(name) usage is not configured yet."
        }
    }
}
