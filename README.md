# vc-funding

> Your coding agent's runway, quietly visible in the macOS menu bar.

[⭐️ Star vc-funding on GitHub](https://github.com/Fran-cois/vc-funding)

![vc-funding in the menu bar](docs/screenshots/menu-bar.png)

<p align="center">
  <img src="docs/screenshots/usage-dropdown.png" alt="Codex usage dropdown" width="46%">
  <img src="docs/screenshots/switch-alert.png" alt="Switch provider warning" width="46%">
</p>

## Features

- Native SwiftUI `MenuBarExtra` for macOS 13+
- Codex 5-hour and weekly usage percentages
- Green, orange, and red status indicators
- Reset countdowns and five-minute automatic refresh
- **Time to switch** alert at 90%
- **Time to burn tokens** alert before unused quota resets
- Deduplicated native macOS notifications
- Launch at login
- Provider tabs ready for Claude Code and future agents
- No analytics, uploads, or credential access

## Install

### Download

Download `vc-funding-0.1.0.zip` from the [latest GitHub release](https://github.com/Fran-cois/vc-funding/releases/latest), move `vc-funding.app` to `/Applications`, and open it.

### Homebrew

Once the Cask is published in the tap:

```sh
brew install --cask vc-funding
```

### Build from source

```sh
git clone https://github.com/Fran-cois/vc-funding.git
cd vc-funding
swift test
./scripts/build-app.sh
open .build/vc-funding.app
```

## Privacy and data source

vc-funding makes no network requests. It reads only Codex `token_count.rate_limits` events from:

```text
$CODEX_HOME/sessions/**/*.jsonl
```

`CODEX_HOME` defaults to `~/.codex`. The app never opens `~/.codex/auth.json`, logs credentials, derives quotas from token counts, or calls undocumented endpoints.

The local event schema is not a documented stable public API. Missing or expired windows are omitted from the menu bar and explained in the dropdown.

## Alerts

| Indicator | Meaning |
| :---: | --- |
| 🟢 | 0–69% used |
| 🟠 | 70–89% used |
| 🔴 | 90–100% used — consider switching |
| 🔥 | At least 20% remains shortly before reset |

The 🔥 window is the final hour of a 5-hour quota or the final 24 hours of a weekly quota. Switch alerts take priority. Each native notification is sent only once per reset window.

## Architecture

```text
Codex session events → CodexUsageProvider → UsageSnapshot
                                                ↓
AgentUsageProvider → UsageStore → MenuBarExtra + alerts
```

Implement `AgentUsageProvider` and register it in `VCFundingApp` to add another coding agent.

## Development

```sh
swift test
./scripts/check-release.sh 0.1.0
```

The suite currently covers parsing, filesystem discovery, expired windows, display state, multiple providers, and alert boundaries. Release instructions are in [`RELEASE.md`](RELEASE.md).

## License

[MIT](LICENSE) © 2026 Fran-cois.
