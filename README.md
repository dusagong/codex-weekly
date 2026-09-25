# Codex Weekly

Weekly Codex usage, at a glance.

![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![Architecture](https://img.shields.io/badge/Apple_Silicon_%26_Intel-Universal-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Codex Weekly is a native macOS menu bar application that displays your remaining weekly Codex usage allowance. Check your balance, reset time, and update status without leaving your current workspace.

**[Download](https://github.com/dusagong/codex-weekly/releases/latest)** · [한국어](README.ko.md) · [Report an issue](https://github.com/dusagong/codex-weekly/issues)

## Features

- **Compact indicator** — an icon and the remaining percentage in the menu bar.
- **Automatic refresh** — updates every minute and when your Mac wakes from sleep.
- **Usage details** — used and remaining allowance, reset time, and the last successful update.
- **Existing Codex login** — retrieves usage through your installed Codex application or CLI.
- **Native implementation** — built with Swift and AppKit, with no third-party Swift dependencies.

## Requirements

| Requirement | Details |
| --- | --- |
| Operating system | macOS 14 or later |
| Processor | Apple Silicon or Intel; one universal download |
| Codex | Codex desktop application or a CLI installation in a supported location |
| Account | A ChatGPT login that provides weekly Codex usage limits |
| Network | Internet access for usage updates |
| Interface language | Korean |

The minimum deployment target is macOS 14. Runtime testing has been performed on Apple Silicon with macOS 26.4.1; Intel and earlier macOS releases have not yet been validated at runtime. API-key-only accounts may not provide weekly usage limits.

## Installation

1. Open the [latest release](https://github.com/dusagong/codex-weekly/releases/latest) and download the macOS universal ZIP.
2. Extract the ZIP and move **Codex Weekly.app** to **Applications**.
3. Open the app. The menu bar indicator appears, and the details window opens on first launch.

Closing the details window keeps the menu bar indicator running. To launch at login, add the app under **System Settings → General → Login Items**.

### First launch

Release builds use an ad-hoc signature and are not Apple Developer ID signed or notarized. If macOS blocks the app, follow [Apple’s instructions for opening a trusted app](https://support.apple.com/en-us/102445), or build from source.

### Verify the download

Download `SHA256SUMS` from the same release and place it beside the ZIP. In that directory, run:

```sh
shasum -a 256 -c SHA256SUMS
```

## Usage

The menu bar percentage represents **remaining weekly allowance**, not an exact token count. Select the indicator to view details or use these controls:

| Menu item | Action |
| --- | --- |
| 사용량 보기… | Open the usage details window |
| 지금 새로고침 | Fetch the latest usage |
| Codex 열기 | Open the installed Codex desktop application |
| 종료 | Quit Codex Weekly |

Reset times use your Mac’s local time zone. A `?` beside a percentage means it is the last known value following a failed update or a stale reading. After the reported reset time passes, the old percentage is hidden until a new fetch succeeds. An unavailable reading is not treated as zero remaining allowance.

## Usage data

Codex Weekly calls [`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server) through the installed Codex executable. Authentication remains with Codex; no separate API key is configured in this app. Usage retrieval does not create model turns or redeem usage-reset credits.

The app reads the general `codex` allowance and identifies the weekly window by its 10,080-minute duration. It uses the account available to the launched Codex process. A custom `CODEX_HOME` or multiple Codex installations can result in a different account from another Codex session.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Codex cannot be found | Install the desktop app or place the CLI at `/opt/homebrew/bin/codex` or `/usr/local/bin/codex`. Custom and nvm-only CLI paths are not discovered automatically. |
| Weekly allowance is unavailable | Check your Codex login and whether the account provides weekly usage limits. |
| A percentage has a `?` marker | Check your internet connection and select **지금 새로고침**. |
| Usage differs from another Codex session | Check which account and `CODEX_HOME` the local Codex process uses. |

Desktop discovery uses macOS application registration and the standard `/Applications` locations.

## Development

Requires **Xcode 16 or later**, or Apple Command Line Tools with **Swift 6**.

```sh
git clone https://github.com/dusagong/codex-weekly.git
cd codex-weekly
./scripts/package.sh
```

| Command | Result |
| --- | --- |
| `./scripts/test.sh` | Run model and transport tests using local fixtures |
| `./scripts/build.sh` | Build and ad-hoc sign the universal application |
| `./scripts/package.sh` | Run tests, build the app, and create the ZIP and checksums |

The application is written to `build/Codex Weekly.app`; release files are written to `build/releases/`. Tests do not access your Codex account or make network requests.

Application sources are in `src/`, test fixtures in `tests/`, and bundle metadata in `Info.plist`.

## Contributing

Bug reports and pull requests are welcome. [Open an issue](https://github.com/dusagong/codex-weekly/issues) with your macOS version, processor, app version, and steps to reproduce. Exclude authentication files, tokens, and account logs. Run `./scripts/test.sh` before submitting code changes.

## License

[MIT](LICENSE). Codex Weekly is an independent project and is not affiliated with or endorsed by OpenAI or Apple.
