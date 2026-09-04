import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedAgent = CodingAgent.codex
    @State private var isShowingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.tint)
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
            usageCard("5-hour window", shortTitle: "5h", window: snapshot?.fiveHour)
            usageCard("Weekly window", shortTitle: "7d", window: snapshot?.weekly)

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
            Text("Open Codex, Claude Code, or Antigravity once, then refresh.")
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
            Label("No credentials, analytics, or uploads", systemImage: "lock.shield")

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
