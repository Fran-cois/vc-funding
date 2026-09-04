# coding-agent-percentage

A private, native macOS menu bar app that shows Codex usage at a glance:

```text
〉_ 5h 42% · 7d 68%
```

The dropdown shows each available usage window, its reset countdown, the last refresh time, and a manual refresh action. It refreshes automatically every five minutes and can register itself to launch at login.

## Privacy and data source

The app is local-only. It makes no network requests, does not read `~/.codex/auth.json`, and never uploads or logs credentials.

Codex CLI 0.153.2 has no documented usage command. The safest available source on this machine is the `rate_limits` object in Codex's local JSONL session events under:

```text
$CODEX_HOME/sessions/**/*.jsonl
```

(`CODEX_HOME` defaults to `~/.codex`.) These `token_count` events are written by Codex itself and include `used_percent`, `window_minutes`, and `resets_at`. The provider reads only recent tails of session files, identifies windows by duration (300 minutes and 10,080 minutes), and keeps the newest non-expired value for each window. It does not infer usage from tokens, inspect authentication state, invoke undocumented endpoints, or bypass authentication.

Because this is a local event stream rather than a documented stable public API, a Codex update may change its schema. If the directory, fields, or a current window are unavailable, the menu bar shows `N/A` and the dropdown explains that there is no current value in local events. Opening or using Codex normally gives it a chance to write a fresh event.

The `AgentUsageProvider` protocol keeps collection independent from the UI, so Claude Code and other agents can be added as new providers without changing the menu bar views.

## Requirements

- macOS 13 or newer
- Xcode / Swift toolchain (verified with Xcode 26.6 and Swift 6.3.3)
- Codex CLI or Codex desktop app with local session history

## Build and test

```sh
swift test
./scripts/build-app.sh
```

The packaged app is created at `.build/coding-agent-percentage.app`. Run it with:

```sh
open .build/coding-agent-percentage.app
```

For a stable install location (recommended before enabling launch at login):

```sh
cp -R .build/coding-agent-percentage.app /Applications/
open /Applications/coding-agent-percentage.app
```

Open **Settings…** from the menu and enable **Launch at login**. macOS may surface the item in System Settings → General → Login Items.

For development, `swift run coding-agent-percentage` also works, but launch-at-login registration requires running the packaged `.app`.

## Project layout

- `AgentUsageProvider`: provider boundary for additional coding agents
- `CodexUsageProvider`: bounded, read-only scan of local Codex session events
- `CodexUsageParser`: pure JSONL parsing and newest-window selection
- `UsageSnapshot`: provider-neutral usage model
- `UsageStore` / `RefreshScheduler`: UI state and five-minute refresh lifecycle
- SwiftUI `MenuBarExtra`, dropdown, and settings views
- Parser tests covering valid, malformed, merged, expired, and clamped input

## License

No license is included. This repository is intended to remain private; without a license, no reuse rights are granted by default.
