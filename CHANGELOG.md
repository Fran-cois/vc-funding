# Changelog

All notable changes to **vc-funding** are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- The **maxeur de plan max** leaderboard prize now also counts maxed-out weekly (7-day) windows, not just 5-hour ones, so an agent whose weekly quota expires fully used shows up too.

## [0.2.0] - 2026-09-11

### Added

- Off-by-default **No-network mode (Codex)** toggle that skips the `codex` CLI call entirely and forces local session-log parsing, with a "not reliable" warning in the info panel.
- Codex's dropdown now shows every metered limit as its own line (e.g. **Codex**, **GPT-5.3-Codex-Spark**, **gpt-reserve**) when read via the CLI, instead of a single aggregated 5-hour/weekly pair.

### Changed

- Codex usage now reads live account rate limits from the `codex` CLI's app-server RPC (`account/rateLimits/read`), the same source the Codex TUI status line uses, falling back to local session-log parsing only if the CLI call is unavailable. Local log parsing alone could show stale figures (e.g. after a quota-exhaustion fallback a given session never logged).

## [0.1.0] - 2026-09-04

### Added

- Native SwiftUI macOS menu bar application
- Local Codex 5-hour and weekly usage parsing
- Five-minute automatic refresh and manual refresh
- Animated money loader in the menu header while refreshing
- Reset countdowns and launch-at-login support
- Codex, Claude Code, and Antigravity provider tabs
- Automatic provider discovery; tabs require usable usage data and otherwise fall back to a friendly empty state
- Documented safe-source limitation for Antigravity usage
- Traffic-light usage indicators with unavailable windows omitted
- Deduplicated **Time to switch coding agent** notifications at 90%
- Deduplicated **Time to burn tokens** notifications before underused quota resets
- Homebrew Cask release tooling
- Privacy-focused documentation and generated demo screenshots
- MIT license
- Documentation of the planned, credential-free Claude Code status-line data source
- Swift Testing coverage for parsing, providers, display state, and notifications

[0.1.0]: https://github.com/Fran-cois/vc-funding/releases/tag/v0.1.0
[0.2.0]: https://github.com/Fran-cois/vc-funding/releases/tag/v0.2.0
