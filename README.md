# Codex Weekly

A small macOS menu bar app that shows your **remaining weekly Codex usage allowance** as a percentage. Native Swift/AppKit, with a compact icon and automatic updates every minute.

[한국어 안내](README.ko.md) · [Download ZIP](https://github.com/dusagong/codex-weekly/releases/download/v1.1.0/Codex-Weekly-v1.1.0-macOS-universal.zip) · [Latest release](https://github.com/dusagong/codex-weekly/releases/latest)

## Install

1. Download the ZIP and double-click it to extract **Codex Weekly.app**.
2. Move the app to **Applications**, then open it.
3. Use the indicator in the top-right menu bar. A details window opens on the first launch; closing it keeps the menu bar indicator running.

The universal release includes Apple Silicon and Intel code and targets **macOS 14 or later**. Runtime validation was performed on an Apple Silicon Mac running macOS 26.4.1; Intel and older macOS runtime behavior has not been tested.

Releases are **ad-hoc signed, not Apple Developer ID signed or notarized**. macOS may block the first launch. Review the source and release checksums, then follow [Apple's per-app opening instructions](https://support.apple.com/en-us/102445) if you trust the app. You can also build from source below. The project does not ask you to disable Gatekeeper.

To start automatically, add the app in **System Settings → General → Login Items**. The app does not enable automatic startup itself.

## Requirements

- Install the **Codex desktop app or Codex CLI** on your own Mac and sign in with your own ChatGPT account that exposes weekly Codex usage limits. A Codex installation or account is not included in this download.
- An internet connection is needed for updates. API-key-only accounts may not provide weekly allowance data.

The desktop app is discovered through macOS application registration and the standard Applications folder. CLI fallback checks only `/opt/homebrew/bin/codex` and `/usr/local/bin/codex`; custom or nvm-only CLI locations are not automatically discovered.

## Usage

The indicator shows values such as **79%**: the remaining proportion of your weekly allowance, not an exact token count. Click it to see usage, reset time, the last successful update, and refresh controls. The interface is currently in Korean:

| Menu label | Meaning |
| --- | --- |
| 사용량 보기… | Open the details window |
| 지금 새로고침 | Refresh now |
| 종료 | Quit the app |

Updates run every minute and after wake. If an update fails or the last successful value becomes stale, `?` marks the last known percentage. Values whose weekly reset time has passed are hidden until a new fetch succeeds. Reset times use the Mac's local time zone.

The app uses the official local Codex executable and [`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server). Codex manages the existing login; this utility does not copy authentication tokens or include the author's account. It does not create model turns or consume reset credits. It selects the general `codex` limit bucket and identifies the weekly window by its 10,080-minute duration.

When using a custom `CODEX_HOME` or multiple accounts, the displayed account is the one available to the launched Codex executable, which can differ from another Codex app or CLI session.

## Build and test

Install **Xcode 16 or later**, or Apple Command Line Tools with **Swift 6**, then:

```sh
git clone https://github.com/dusagong/codex-weekly.git
cd codex-weekly
./scripts/package.sh
```

`package.sh` runs the offline tests, builds both architectures, checks the ad-hoc signature, and creates:

- `build/Codex Weekly.app`
- `build/releases/Codex-Weekly-v1.1.0-macOS-universal.zip`
- `build/releases/SHA256SUMS`

You can also run `./scripts/test.sh` and `./scripts/build.sh` separately. The model and transport tests use local fixtures; they do not access your Codex account or make network requests. No third-party Swift packages are needed. App sources are in `src/`, tests in `tests/`, and bundle metadata in `Info.plist`.

To verify a downloaded release, place its ZIP and `SHA256SUMS` in the same directory and run `shasum -a 256 -c SHA256SUMS` there.

## Contributing

[Open an issue](https://github.com/dusagong/codex-weekly/issues) with your macOS version, processor type, app version, and a description of the problem. Do not include authentication files, access tokens, or account logs. Pull requests are welcome; run the local tests before submitting.

Licensed under the [MIT License](LICENSE). This is an independent project, not an official Apple or OpenAI product.
