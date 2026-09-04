import Foundation

protocol AgentUsageProvider: Sendable {
    var agentName: String { get }
    func fetchUsage() async throws -> UsageSnapshot
}
