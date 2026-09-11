import Foundation

/// Tracks, per agent and per ISO week (UTC), how many distinct usage windows (5-hour or weekly) were
/// observed maxed out. This feeds the "maxeur de plan max" leaderboard prize. Local-only bookkeeping,
/// resets every new week.
@MainActor
final class MaxedCycleTracker: ObservableObject {
    private static let maxedThresholdPercent = 95.0
    private static let storageKey = "MaxedCycleTrackerStateV1"

    private struct State: Codable {
        var weekId: String
        var countsByAgent: [String: Int]
        var countedResets: [String: [String]]
    }

    private let defaults: UserDefaults
    private var state: State

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        let weekId = Self.weekId(for: now)
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(State.self, from: data),
           decoded.weekId == weekId {
            state = decoded
        } else {
            state = State(weekId: weekId, countsByAgent: [:], countedResets: [:])
        }
    }

    /// Counts a maxed window (5-hour or weekly) once per distinct reset boundary per agent per week.
    func recordObservation(agent: String, window: UsageWindow?, now: Date = Date()) {
        rolloverIfNeeded(now: now)
        guard let window, window.usedPercent >= Self.maxedThresholdPercent else { return }
        let resetKey = ISO8601DateFormatter().string(from: window.resetsAt)
        var seen = state.countedResets[agent] ?? []
        guard !seen.contains(resetKey) else { return }
        seen.append(resetKey)
        state.countedResets[agent] = seen
        state.countsByAgent[agent, default: 0] += 1
        persist()
    }

    func countsThisWeek(now: Date = Date()) -> [String: Int] {
        rolloverIfNeeded(now: now)
        return state.countsByAgent
    }

    private func rolloverIfNeeded(now: Date) {
        let currentWeekId = Self.weekId(for: now)
        guard currentWeekId != state.weekId else { return }
        state = State(weekId: currentWeekId, countsByAgent: [:], countedResets: [:])
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func weekId(for date: Date, calendar: Calendar = Calendar(identifier: .iso8601)) -> String {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }
}
