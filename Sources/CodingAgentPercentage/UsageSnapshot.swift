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
    /// Raw consumption for unlimited plans (e.g. Copilot), where there is no cap to compute a percentage against.
    let creditsUsed: Int?
    /// Authoritative USD amount for the current cycle, computed by the provider from its own units. Used for the euro estimate.
    let costUSD: Double?

    init(
        agentName: String,
        fiveHour: UsageWindow?,
        weekly: UsageWindow?,
        refreshedAt: Date,
        sourceUpdatedAt: Date,
        creditsUsed: Int? = nil,
        costUSD: Double? = nil
    ) {
        self.agentName = agentName
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.refreshedAt = refreshedAt
        self.sourceUpdatedAt = sourceUpdatedAt
        self.creditsUsed = creditsUsed
        self.costUSD = costUSD
    }
}

enum UsageProviderError: LocalizedError, Equatable {
    case sessionsDirectoryMissing
    case noUsageData
    case unsupportedAgent(String)
    case networkOptInRequired(String)
    case credentialsNotFound(String)
    case credentialsRejected(String)
    case unlimitedQuota(String)
    case networkRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .sessionsDirectoryMissing:
            "Codex session storage was not found. Run Codex and try again."
        case .noUsageData:
            "No current Codex usage snapshot is available yet."
        case .unsupportedAgent(let name):
            "\(name) usage is not configured yet."
        case .networkOptInRequired(let name):
            "\(name) usage needs network access. Enable it in the app info panel."
        case .credentialsNotFound(let name):
            "No local \(name) sign-in was found. Sign in via an editor extension or the gh CLI first."
        case .credentialsRejected(let name):
            "GitHub rejected the local \(name) credential. Try `gh auth login` or sign in to Copilot again."
        case .unlimitedQuota(let name):
            "\(name) is on an unlimited plan, so there is no percentage quota to show."
        case .networkRequestFailed(let name):
            "\(name) usage request failed. Check your network connection and subscription."
        }
    }
}
