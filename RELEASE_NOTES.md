# vc-funding 0.2.0

This release makes Codex usage live and detailed: numbers come straight from the `codex` CLI instead of local logs alone, broken down per metered limit.

## Highlights

- Codex usage now reads live account rate limits via the `codex` CLI's app-server RPC (`account/rateLimits/read`) — the same source the Codex TUI status line uses — falling back to local session-log parsing only if the CLI call is unavailable.
- Codex's dropdown shows every metered limit as its own line (e.g. **Codex**, **GPT-5.3-Codex-Spark**, **gpt-reserve**) instead of a single aggregated 5-hour/weekly pair.
- New off-by-default **No-network mode (Codex)** toggle that skips the CLI call entirely and forces local log parsing, clearly marked "not reliable" in the info panel.
- Get a clear red warning and one native notification when it is time to switch providers.
- Get a 🔥 reminder when unused quota is close to resetting.
- Use, modify, and redistribute the project under the MIT license.
- Install from a GitHub release archive or a Homebrew Cask once its tap is connected.

## Requirements

- macOS 13 or newer
- The `codex` CLI installed and signed in (recommended), or local Codex session history as a fallback

## Known limitation

Claude Code has a prepared UI tab but no data provider yet. The downloadable development build is ad-hoc signed; production distribution should use Apple Developer ID signing and notarization.

