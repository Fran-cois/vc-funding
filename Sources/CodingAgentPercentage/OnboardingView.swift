import AppKit
import SwiftUI

/// Shown once on first launch (until dismissed). A MenuBarExtra app has no Dock icon or
/// main window, so without this the app is invisible to someone who just installed it.
struct OnboardingView: View {
    let dismiss: () -> Void

    private static let shownKey = "OnboardingShown"

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: shownKey)
    }

    static func markShown() {
        UserDefaults.standard.set(true, forKey: shownKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("🤑").font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.pick("Welcome to vc-funding", "Bienvenue dans vc-funding"))
                        .font(.title2.bold())
                    Text(L10n.pick(
                        "Reverse VC funding, straight from your menu bar.",
                        "Le reverse VC funding, directement dans ta barre de menus."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow("menubar.and.rectangle", L10n.pick(
                    "Lives in the menu bar",
                    "Vit dans la barre de menus"
                ), L10n.pick(
                    "Your 5-hour and weekly usage at a glance, next to the clock.",
                    "Ton usage 5 h et hebdo en un coup d'œil, à côté de l'horloge."
                ))
                featureRow("square.stack.3d.up", L10n.pick(
                    "Tracks every coding agent",
                    "Suit tous tes agents de code"
                ), L10n.pick(
                    "Codex, Claude Code, Antigravity, GitHub Copilot, OpenRouter, Cursor.",
                    "Codex, Claude Code, Antigravity, GitHub Copilot, OpenRouter, Cursor."
                ))
                featureRow("trophy.fill", L10n.pick(
                    "Weekly leaderboard",
                    "Classement hebdomadaire"
                ), L10n.pick(
                    "Compare your burn with everyone else's — sharing is opt-in.",
                    "Compare ta consommation aux autres — le partage est opt-in."
                ))
            }

            HStack {
                Spacer()
                Button(L10n.pick("Get started", "C'est parti")) {
                    OnboardingView.markShown()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(26)
        .frame(width: 420)
    }

    private func featureRow(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .frame(width: 26, height: 26)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Owns the small onboarding window so the App scene stays menu-bar-only.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func showIfNeeded() {
        guard OnboardingView.shouldShow, window == nil else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "vc-funding"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView(dismiss: { [weak self] in
            self?.window?.close()
        }))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
