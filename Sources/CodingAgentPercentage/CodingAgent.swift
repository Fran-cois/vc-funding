import AppKit
import Foundation
import SwiftUI

enum CodingAgent: String, CaseIterable, Identifiable, Sendable {
    case codex = "Codex"
    case claudeCode = "Claude Code"
    case antigravity = "Antigravity"
    case githubCopilot = "GitHub Copilot"
    case openRouter = "OpenRouter"
    case cursor = "Cursor"

    var id: String { rawValue }

    /// Official provider logo, monochrome white on transparent (see Resources/Icons).
    /// Sources: simple-icons.org (CC0) for Anthropic / GitHub Copilot / OpenRouter / Cursor,
    /// Wikimedia Commons for the OpenAI symbol and the Google Antigravity mark.
    private var iconResourceName: String {
        switch self {
        case .codex: "codex"
        case .claudeCode: "claude-code"
        case .antigravity: "antigravity"
        case .githubCopilot: "github-copilot"
        case .openRouter: "openrouter"
        case .cursor: "cursor"
        }
    }

    /// Fallback SF Symbol used only if the bundled SVG icon can't be loaded.
    var symbolName: String {
        switch self {
        case .codex: "terminal.fill"
        case .claudeCode: "sparkles"
        case .antigravity: "atom"
        case .githubCopilot: "chevron.left.forwardslash.chevron.right"
        case .openRouter: "arrow.triangle.branch"
        case .cursor: "cursorarrow.rays"
        }
    }

    var logoImage: Image {
        if let url = Bundle.module.url(forResource: iconResourceName, withExtension: "svg", subdirectory: "Icons"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: symbolName)
    }

    var brandColor: Color {
        switch self {
        case .codex: Color(red: 0x10 / 255, green: 0xA3 / 255, blue: 0x7F / 255) // OpenAI teal
        case .claudeCode: Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255) // Anthropic clay
        case .antigravity: Color(red: 0x42 / 255, green: 0x85 / 255, blue: 0xF4 / 255) // Google blue
        case .githubCopilot: Color(red: 0x89 / 255, green: 0x57 / 255, blue: 0xE5 / 255) // GitHub Copilot purple
        case .openRouter: Color(red: 0x64 / 255, green: 0x67 / 255, blue: 0xF2 / 255) // OpenRouter indigo
        case .cursor: Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255) // Cursor near-black
        }
    }
}

struct UnavailableAgentUsageProvider: AgentUsageProvider {
    let agentName: String

    func fetchUsage() async throws -> UsageSnapshot {
        throw UsageProviderError.unsupportedAgent(agentName)
    }
}
