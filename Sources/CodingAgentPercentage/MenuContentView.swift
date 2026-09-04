import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Codex usage").font(.headline)
            usageRow("Current 5h", window: store.snapshot?.fiveHour)
            usageRow("Weekly", window: store.snapshot?.weekly)

            Divider()
            detailRow("Last refresh", value: store.snapshot.map { Self.relativeText(for: $0.refreshedAt) } ?? "Never")

            if let error = store.errorMessage {
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
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func usageRow(_ title: String, window: UsageWindow?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            detailRow(title, value: window.map { "\($0.roundedPercent)%" } ?? "Unavailable")
            if let window {
                Text("Resets \(Self.relativeText(for: window.resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
