import AppKit
import ImageIO
import SwiftUI

struct DemoProviderLogo: View {
    let iconFileName: String
    let color: Color

    private static let iconsDirectory: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CodingAgentPercentage/Resources/Icons", isDirectory: true)
    }()

    private var iconImage: Image {
        let url = Self.iconsDirectory.appendingPathComponent("\(iconFileName).svg")
        if let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(color.gradient)
            iconImage.resizable().scaledToFit().frame(width: 13, height: 13)
        }
        .frame(width: 24, height: 24)
    }
}

struct DemoLineCard: View {
    let name: String
    let fiveHour: Int?
    let weekly: Int?

    private func color(_ percent: Int) -> Color {
        percent >= 90 ? .red : (percent >= 70 ? .orange : .green)
    }

    private func stat(_ label: String, _ percent: Int?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let percent {
                Text("\(percent)%").font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(color(percent))
            } else {
                Text("—").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.subheadline.weight(.semibold))
            HStack(spacing: 14) {
                stat("5h", fiveHour)
                stat("7d", weekly)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DemoDropdown: View {
    let alert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                DemoProviderLogo(iconFileName: "codex", color: Color(red: 0x10 / 255, green: 0xA3 / 255, blue: 0x7F / 255))
                VStack(alignment: .leading, spacing: 1) {
                    Text("VC funding").font(.title3.bold())
                    Text("Codex usage").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !alert {
                    Image(systemName: "dollarsign.circle.fill").font(.title2).foregroundStyle(.green)
                }
            }

            Text("Codex")
                .frame(maxWidth: .infinity)
                .padding(7)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))

            if alert {
                Label("5h usage is at 95%. Consider switching coding agent.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.bold()).foregroundStyle(.white).padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 12))
            }

            DemoLineCard(name: "Codex", fiveHour: nil, weekly: alert ? 91 : 42)
            DemoLineCard(name: "GPT-5.3-Codex-Spark", fiveHour: alert ? 95 : 8, weekly: alert ? 78 : 35)
            DemoLineCard(name: "gpt-reserve", fiveHour: nil, weekly: alert ? 45 : 22)

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
                Spacer()
                Text("Quit").padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Image(systemName: "questionmark.circle")
                    .font(.title3)
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
        .padding(8)
        .background(Color.clear)
        .environment(\.colorScheme, .dark)
    }
}

struct DemoSegmentedPicker: View {
    let items: [String]
    let selected: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(item == selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(item == selected ? Color.white.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DemoCreditsCard: View {
    let credits: Int
    let euro: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Credits").font(.title2.bold())
                Text("Unlimited plan — usage this cycle").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(credits)").font(.title.bold()).monospacedDigit()
                Text("(\(euro))").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DemoCopilotDropdown: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                DemoProviderLogo(
                    iconFileName: "github-copilot",
                    color: Color(red: 0x89 / 255, green: 0x57 / 255, blue: 0xE5 / 255)
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text("VC funding").font(.title3.bold())
                    Text("GitHub Copilot usage").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            DemoSegmentedPicker(
                items: ["Codex", "Claude Code", "Antigravity", "GitHub Copilot"],
                selected: "GitHub Copilot"
            )

            DemoCreditsCard(credits: 222_157, euro: "≈ 1 910,10 €")

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
                Spacer()
                Text("Quit").padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Image(systemName: "questionmark.circle")
                    .font(.title3)
            }
        }
        .padding(22)
        .frame(width: 360)
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
            Circle().fill(.green).frame(width: 12, height: 12)
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
        try render(DemoCopilotDropdown(), to: output.appendingPathComponent("copilot-credits.png"))
    }

    static func render<V: View>(_ view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let sourceImage = renderer.cgImage else {
            throw NSError(domain: "vc-funding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(url.lastPathComponent)"])
        }
        let width = sourceImage.width
        let height = sourceImage.height
        // BGRA byte order matches Truevision TGA's pixel layout, so no channel swap is needed below.
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ), let data = context.data else {
            throw NSError(domain: "vc-funding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not normalize \(url.lastPathComponent)"])
        }
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // This OS build's in-process ImageIO write plugins (PNG/TIFF) crash with
        // SIGBUS/EXC_ARM_DA_ALIGN for images produced by ImageRenderer, so the raw pixels are
        // written out as an uncompressed TGA by hand (no ImageIO involved) and handed to the
        // external, unaffected `sips` tool for the final PNG conversion.
        var tga = Data(capacity: 18 + width * height * 4)
        tga.append(contentsOf: [0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        tga.append(UInt8(width & 0xFF)); tga.append(UInt8((width >> 8) & 0xFF))
        tga.append(UInt8(height & 0xFF)); tga.append(UInt8((height >> 8) & 0xFF))
        tga.append(32) // bits per pixel
        tga.append(0x28) // 8 alpha bits + top-down origin (CGContext's raw buffer is bottom-up otherwise)
        tga.append(Data(bytes: data, count: width * height * 4))

        let tgaURL = url.deletingPathExtension().appendingPathExtension("tga")
        try tga.write(to: tgaURL)
        defer { try? FileManager.default.removeItem(at: tgaURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-s", "format", "png", tgaURL.path, "--out", url.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "vc-funding", code: 1, userInfo: [NSLocalizedDescriptionKey: "sips failed to convert \(url.lastPathComponent)"])
        }
    }
}
