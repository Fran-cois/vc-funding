import AppKit
import SwiftUI

struct UsageCard: View {
    let label: String
    let title: String
    let percent: Int
    let reset: String

    var color: Color {
        percent >= 90 ? .red : (percent >= 70 ? .orange : .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.title2.bold())
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(percent)%")
                    .font(.title.bold()).monospacedDigit().foregroundStyle(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * Double(percent) / 100)
                }
            }
            .frame(height: 8)
            Text("Resets \(reset)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DemoDropdown: View {
    let alert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("VC funding").font(.title3.bold())
                    Text("Codex usage").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                Text("Codex").frame(maxWidth: .infinity).padding(7)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                Text("Claude Code").frame(maxWidth: .infinity).padding(7)
            }
            .padding(3)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 9))

            if alert {
                Label("5h usage is at 95%. Consider switching coding agent.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.bold()).foregroundStyle(.white).padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 12))
            }

            UsageCard(label: "5h", title: "5-hour window", percent: alert ? 95 : 42, reset: "in 2 hours")
            UsageCard(label: "7d", title: "Weekly window", percent: 68, reset: "in 3 days")

            Divider()
            HStack {
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                Text("Last refresh")
                Spacer()
                Text("now").foregroundStyle(.secondary)
            }
            HStack {
                Text("Refresh").padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text("Settings…").padding(.horizontal, 14).padding(.vertical, 7)
                Spacer()
                Text("Quit").padding(.horizontal, 14).padding(.vertical, 7)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
        .padding(8)
        .background(Color.clear)
        .environment(\.colorScheme, .dark)
    }
}

struct DemoMenuBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
            Text("🟢")
            Text("5h 42% · 7d 68%").fontWeight(.medium).monospacedDigit()
        }
        .font(.system(size: 18))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(8)
        .environment(\.colorScheme, .dark)
    }
}

@main
@MainActor
struct DemoScreenshotRenderer {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "vc-funding", code: 64, userInfo: [NSLocalizedDescriptionKey: "Pass an output directory"])
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try render(DemoMenuBar(), to: output.appendingPathComponent("menu-bar.png"))
        try render(DemoDropdown(alert: false), to: output.appendingPathComponent("usage-dropdown.png"))
        try render(DemoDropdown(alert: true), to: output.appendingPathComponent("switch-alert.png"))
    }

    static func render<V: View>(_ view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "vc-funding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(url.lastPathComponent)"])
        }
        try png.write(to: url)
    }
}
