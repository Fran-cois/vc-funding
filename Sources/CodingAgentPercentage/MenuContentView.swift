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
                    Text("\(selectedAgent.rawValue) usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }

            Picker("Coding agent", selection: $selectedAgent) {
                ForEach(CodingAgent.allCases) { agent in
                    Text(agent.rawValue).tag(agent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

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

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing { ProgressView().controlSize(.small) }
                    else { Text("Refresh") }
                }
                .disabled(store.isRefreshing)

                Button("Settings…") {
                    NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
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

private struct InfoPopoverView: View {
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
            Label("No credentials, analytics, or uploads", systemImage: "lock.shield")
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
}
