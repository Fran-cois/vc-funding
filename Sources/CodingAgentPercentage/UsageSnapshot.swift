import Foundation

struct UsageWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    var roundedPercent: Int { Int(usedPercent.rounded()) }
}

/// One named quota line within a provider that meters several limits separately (e.g. Codex breaks
/// usage down per model/reserve: "Codex", "GPT-5.3-Codex-Spark", "gpt-reserve"...).
struct UsageLine: Equatable, Sendable, Identifiable {
    let name: String
    let fiveHour: UsageWindow?
    let weekly: UsageWindow?

    var id: String { name }
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
    /// Per-limit breakdown, when the provider meters more than one line (e.g. Codex's model/reserve buckets). Empty otherwise.
    let lines: [UsageLine]

    init(
        agentName: String,
        fiveHour: UsageWindow?,
        weekly: UsageWindow?,
        refreshedAt: Date,
        sourceUpdatedAt: Date,
        creditsUsed: Int? = nil,
        costUSD: Double? = nil,
        lines: [UsageLine] = []
    ) {
        self.agentName = agentName
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.refreshedAt = refreshedAt
        self.sourceUpdatedAt = sourceUpdatedAt
        self.creditsUsed = creditsUsed
        self.costUSD = costUSD
        self.lines = lines
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
