import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    let maxedCycleTracker: MaxedCycleTracker
    @State private var selectedAgent = CodingAgent.codex
    @State private var isShowingInfo = false
    @State private var isShowingLeaderboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ProviderLogoView(agent: selectedAgent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("VC funding").font(.headline)
                    Text(store.availableAgents.isEmpty ? "No providers detected" : "\(selectedAgent.rawValue) usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isRefreshing {
                    MoneyLoaderView()
                }
            }

            if store.availableAgents.isEmpty {
                emptyState
            } else {
                Picker("Coding agent", selection: $selectedAgent) {
                    ForEach(store.availableAgents) { agent in
                        Text(agent.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .tag(agent)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                providerContent
            }

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing { ProgressView().controlSize(.small) }
                    else { Text("Refresh") }
                }
                .disabled(store.isRefreshing)

                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                Button {
                    isShowingLeaderboard.toggle()
                } label: {
                    Image(systemName: "trophy.fill")
                }
                .buttonStyle(.borderless)
                .help("Weekly leaderboard")
                .popover(isPresented: $isShowingLeaderboard, arrowEdge: .bottom) {
                    LeaderboardPopoverView(store: store, maxedCycleTracker: maxedCycleTracker)
                }
                Button {
                    isShowingInfo.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("About vc-funding")
                .popover(isPresented: $isShowingInfo, arrowEdge: .bottom) {
                    InfoPopoverView()
                }
            }
        }
        .padding(12)
        .frame(width: 320)
        .onAppear { selectFirstAvailableAgent() }
        .onChange(of: store.availableAgents) { _ in selectFirstAvailableAgent() }
    }

    @ViewBuilder
    private var providerContent: some View {
        if let reason = store.switchReason(for: selectedAgent) {
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.gradient, in: RoundedRectangle(cornerRadius: 9))
        } else if let reason = store.burnReason(for: selectedAgent) {
                Label(reason, systemImage: "flame.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 9))
        }

            let snapshot = store.snapshot(for: selectedAgent)
            if let costUSD = snapshot?.costUSD, snapshot?.fiveHour == nil, snapshot?.weekly == nil {
                creditsCard(credits: snapshot?.creditsUsed, costUSD: costUSD)
            } else {
                usageCard("5-hour window", shortTitle: "5h", window: snapshot?.fiveHour)
                usageCard("Weekly window", shortTitle: "7d", window: snapshot?.weekly)
            }

            Divider()
            Label {
                detailRow("Last refresh", value: snapshot.map { Self.relativeText(for: $0.refreshedAt) } ?? "Never")
            } icon: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }

            if let error = store.errorMessage(for: selectedAgent) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("💸")
                .font(.system(size: 34))
            Text("No VC funding found…")
                .font(.headline)
            Text("Open Codex, Claude Code, Antigravity, or GitHub Copilot once, then refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func selectFirstAvailableAgent() {
        guard !store.availableAgents.contains(selectedAgent),
              let first = store.availableAgents.first else { return }
        selectedAgent = first
    }

    private func usageCard(_ title: String, shortTitle: String, window: UsageWindow?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortTitle)
                        .font(.title3.weight(.semibold))
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let window {
                    Text("\(window.roundedPercent)%")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(usageColor(window.usedPercent))
                }
            }

            if let window {
                ProgressView(value: window.usedPercent, total: 100)
                    .tint(usageColor(window.usedPercent))
                Text("Resets \(Self.relativeText(for: window.resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: 0, total: 100)
                    .tint(.secondary)
                Text("No current value for \(selectedAgent.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
    }

    private func creditsCard(credits: Int?, costUSD: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(credits != nil ? "Credits" : "Cost")
                        .font(.title3.weight(.semibold))
                    Text("Unlimited plan — usage this cycle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let credits {
                        Text("\(credits)")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("(\(Self.approximateEuroAmount(forUSD: costUSD)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Self.approximateEuroAmount(forUSD: costUSD))
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
    }

    /// EUR uses a static approximate rate, not a live quote; each provider computes its own authoritative USD figure.
    private static let approximateEURPerUSD = 0.86

    private static func approximateEuroAmount(forUSD usd: Double) -> String {
        let euros = usd * approximateEURPerUSD
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = euros >= 100 ? 0 : 2
        let amount = formatter.string(from: NSNumber(value: euros)) ?? String(format: "%.2f €", euros)
        return "≈ \(amount)"
    }

    private func usageColor(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .green
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static func relativeText(for date: Date) -> String {
        relative.string(for: date) ?? "at an unknown time"
    }
}

struct ProviderLogoView: View {
    let agent: CodingAgent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(agent.brandColor.gradient)
            agent.logoImage
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
        }
        .frame(width: 24, height: 24)
    }
}

private struct MoneyLoaderView: View {
    @State private var isAnimating = false

    var body: some View {
        Text("💸")
            .font(.system(size: 20))
            .rotationEffect(.degrees(isAnimating ? 8 : -8))
            .scaleEffect(isAnimating ? 1.08 : 0.9)
            .offset(y: isAnimating ? -2 : 2)
            .animation(
                .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityLabel("Refreshing usage")
    }
}

private struct InfoPopoverView: View {
    @StateObject private var login = LoginItemManager()
    @StateObject private var copilotUsageSettings = CopilotNetworkUsageSettings()
    @StateObject private var openRouterSettings = OpenRouterSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("vc-funding")
                        .font(.headline)
                    Text("Coding-agent runway at a glance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            infoRow("🟢", "0–69%", "Plenty of runway")
            infoRow("🟠", "70–89%", "Keep an eye on it")
            infoRow("🔴", "90–100%", "Time to switch")
            infoRow("🔥", "Before reset", "Time to burn tokens")

            Divider()

            Label("Reads local Codex session events only", systemImage: "folder")
            Label("Claude Code status-line sync: not configured", systemImage: "link.badge.plus")
            Label("Antigravity quota sync: not configured", systemImage: "link.badge.plus")
            Label("GitHub Copilot quota sync: opt-in below, off by default", systemImage: "link.badge.plus")
            Label("No credentials, analytics, or uploads unless you opt in below", systemImage: "lock.shield")

            Divider()

            Toggle("Enable GitHub Copilot usage (network)", isOn: Binding(
                get: { copilotUsageSettings.isEnabled },
                set: { copilotUsageSettings.isEnabled = $0 }
            ))
            Text("⚠️ Reads your local GitHub Copilot sign-in and calls api.github.com to show quota. Unlike every other provider, this leaves your Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Enable OpenRouter usage (network)", isOn: Binding(
                get: { openRouterSettings.isEnabled },
                set: { openRouterSettings.isEnabled = $0 }
            ))
            if openRouterSettings.isEnabled {
                SecureField("OpenRouter API key", text: $openRouterSettings.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            Text("⚠️ Sends your own OpenRouter API key to openrouter.ai to read weekly spend. Stored in the Keychain, never written to disk elsewhere.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { login.isEnabled },
                set: { login.setEnabled($0) }
            ))
            if let error = login.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            HStack {
                Text("Version \(Self.appVersion)")
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: Self.repositoryURL) {
                    Label("Please star on GitHub", systemImage: "star.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .font(.caption)
        .padding(14)
        .frame(width: 280)
    }

    private func infoRow(_ icon: String, _ range: String, _ meaning: String) -> some View {
        HStack(spacing: 8) {
            Text(icon).frame(width: 22)
            Text(range).monospacedDigit().frame(width: 76, alignment: .leading)
            Text(meaning).foregroundStyle(.secondary)
        }
    }

    private static let appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    }()

    private static let repositoryURL = URL(string: "https://github.com/Fran-cois/vc-funding")!
}

private struct LeaderboardPopoverView: View {
    @ObservedObject var store: UsageStore
    let maxedCycleTracker: MaxedCycleTracker
    @StateObject private var settings = LeaderboardSettings()
    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.pick("Weekly leaderboard", "Classement hebdomadaire")).font(.headline)
                    Text(viewModel.standings.map { "\(L10n.pick("Week", "Semaine")) \($0.weekId)" } ?? L10n.pick("Not loaded yet", "Pas encore chargé"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isBusy { ProgressView().controlSize(.small) }
            }

            Divider()

            prizeSection(
                title: "🏆 Maxeur de plan max",
                subtitle: L10n.pick("Most 5-hour windows maxed out this week", "Plus de fenêtres de 5 h saturées cette semaine"),
                entries: viewModel.standings?.maxPlan ?? [],
                valueText: { Self.maxedText($0) }
            )

            prizeSection(
                title: "💸 Reverse VC funding",
                subtitle: L10n.pick("Most spent out of pocket this week", "Plus grosse somme dépensée de sa poche cette semaine"),
                entries: viewModel.standings?.reverseVcFunding ?? [],
                valueText: Self.currencyText
            )

            Button {
                let weekId = viewModel.standings?.weekId
                let url = LeaderboardClient.dashboardURL(weekId: weekId)
                NSWorkspace.shared.open(url)
            } label: {
                Label(L10n.pick("View full dashboard", "Voir le dashboard complet"), systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)

            Divider()

            Toggle(L10n.pick("Share my stats (voluntary)", "Partager mes stats (volontaire)"), isOn: $settings.isEnabled)
            if settings.isEnabled {
                TextField(L10n.pick("Handle (GitHub or nickname)", "Pseudo (GitHub ou surnom)"), text: $settings.handle)
                    .textFieldStyle(.roundedBorder)
                Text(L10n.pick(
                    "⚠️ Your handle and weekly stats become public on this leaderboard. There is no login, so anyone can post any handle/number — treat scores as for fun, not verified.",
                    "⚠️ Ton pseudo et tes stats hebdo deviennent publics sur ce classement. Pas de connexion : n'importe qui peut poster n'importe quel pseudo/chiffre — à prendre pour du fun, non vérifié."
                ))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task {
                        await viewModel.share(
                            handle: settings.handle,
                            maxedCounts: maxedCycleTracker.countsThisWeek(),
                            costsUSD: costsUSDByAgent()
                        )
                    }
                } label: {
                    Text(L10n.pick("Share my stats", "Partager mes stats"))
                }
                .disabled(settings.handle.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isBusy)
                if let sharedAt = viewModel.lastSharedAt {
                    Text("\(L10n.pick("Shared", "Partagé")) \(Self.relativeText(for: sharedAt))")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.caption)
        .padding(14)
        .frame(width: 320)
        .task { await viewModel.refreshStandings() }
    }

    private func costsUSDByAgent() -> [String: Double] {
        Dictionary(uniqueKeysWithValues: store.snapshots.compactMap { agentName, snapshot in
            snapshot.costUSD.map { (agentName, $0) }
        })
    }

    @ViewBuilder
    private func prizeSection(
        title: String,
        subtitle: String,
        entries: [LeaderboardEntry],
        valueText: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            Text(subtitle).foregroundStyle(.secondary)
            if entries.isEmpty {
                Text(L10n.pick("No entries yet this week.", "Aucune entrée pour l'instant cette semaine.")).foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.prefix(10).enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text("\(index + 1).").monospacedDigit().frame(width: 18, alignment: .leading)
                        Text(Self.flag(for: entry.country))
                        Text(entry.handle).lineLimit(1)
                        Spacer()
                        Text(valueText(entry.value)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }

    private static func flag(for countryCode: String?) -> String {
        guard let countryCode, countryCode.count == 2,
              countryCode.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) })
        else { return "🏳️" }
        let base: UInt32 = 127_397
        let scalars = countryCode.unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }
        guard scalars.count == 2 else { return "🏳️" }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func maxedText(_ value: Double) -> String {
        let n = Int(value.rounded())
        return L10n.isFrench ? "\(n) saturée\(n == 1 ? "" : "s")" : "\(n) maxed"
    }

    private static func currencyText(_ usd: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = L10n.formattingLocale
        formatter.maximumFractionDigits = usd >= 100 ? 0 : 2
        return formatter.string(from: NSNumber(value: usd)) ?? String(format: "$%.2f", usd)
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static func relativeText(for date: Date) -> String {
        relative.string(for: date) ?? "just now"
    }
}

