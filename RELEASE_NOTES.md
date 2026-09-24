# vc-funding 0.3.0

This release adds Claude Code usage. You can now watch your Claude Code limits alongside Codex.

## Highlights

- **Claude Code** tab: 5-hour session and weekly usage percentages with reset times. The numbers come from the `claude` CLI's own `/usage` command. It runs locally, uses no tokens and reads no credentials.
- The app finds `claude` even when it's installed in `~/.local/bin` (the native installer's location), which apps opened from Finder can't see on their `PATH`.
- The **maxeur de plan max** leaderboard now also counts maxed-out weekly windows, not just 5-hour ones.

## Requirements

- macOS 13 or newer
- For Codex: the `codex` CLI installed and signed in (recommended), or local Codex session history as a fallback
- For Claude Code: the `claude` CLI installed and signed in with a Claude subscription

## Known limitation

The menu bar label still shows only Codex's numbers. Claude Code usage appears in the dropdown. The downloadable development build is ad-hoc signed; production distribution should use Apple Developer ID signing and notarization.
