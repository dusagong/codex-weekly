# Codex Weekly

메뉴 막대에서 확인하는 Codex 주간 사용량.

![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![Architecture](https://img.shields.io/badge/Apple_Silicon_%26_Intel-Universal-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Codex Weekly는 macOS 메뉴 막대에 Codex 주간 사용 한도의 남은 비율을 표시하는 네이티브 앱입니다. 잔량, 한도 초기화 시각, 갱신 상태를 확인하고 초기화까지 남은 시간과 사용 한도를 비교할 수 있습니다.

**[다운로드](https://github.com/dusagong/codex-weekly/releases/latest)** · [English](README.md) · [문제 보고](https://github.com/dusagong/codex-weekly/issues)

## 주요 기능

- **간결한 메뉴 막대 표시** — 아이콘과 남은 비율을 함께 표시합니다.
- **자동 갱신** — 1분마다, 그리고 Mac이 잠자기에서 깨어날 때 사용량을 조회합니다.
- **상세 사용량** — 사용한 비율, 남은 비율, 초기화 시각, 마지막 조회 시간을 확인합니다.
- **주간 잔여 시간 비교** — 메뉴와 상세 창에서 남은 한도와 시간을 비교합니다. 상세 창의 두 막대와 균등 사용 기준 대비 차이로 사용 속도를 확인합니다.
- **기존 Codex 로그인 사용** — 설치된 Codex 앱 또는 CLI를 통해 사용량을 조회합니다.
- **네이티브 구현** — 외부 Swift 패키지 의존성 없이 Swift와 AppKit으로 구현했습니다.

## 요구 사항

| 항목 | 요구 사항 |
| --- | --- |
| 운영체제 | macOS 14 이상 |
| 프로세서 | Apple Silicon 또는 Intel — 하나의 범용 앱으로 제공 |
| Codex | Codex 데스크톱 앱 또는 지원 경로에 설치된 CLI |
| 계정 | Codex 주간 사용 한도를 제공하는 ChatGPT 로그인 |
| 네트워크 | 사용량 조회를 위한 인터넷 연결 |
| 앱 표시 언어 | 한국어 |

최소 빌드 대상은 macOS 14입니다. 실제 실행은 Apple Silicon 및 macOS 26.4.1에서 검증했으며, Intel과 이전 macOS 버전에서의 실행은 아직 검증하지 않았습니다. API 키만 사용하는 계정에서는 주간 사용 한도가 제공되지 않을 수 있습니다.

## 설치

1. [최신 릴리스](https://github.com/dusagong/codex-weekly/releases/latest)에서 macOS 범용 ZIP 파일을 다운로드합니다.
2. 압축을 풀고 **Codex Weekly.app**을 **응용 프로그램** 폴더로 옮깁니다.
3. 앱을 실행합니다. 메뉴 막대에 잔량이 표시되며, 첫 실행 시 상세 창이 열립니다.

상세 창을 닫아도 메뉴 막대 표시는 유지됩니다. 로그인 시 자동으로 실행하려면 **시스템 설정 → 일반 → 로그인 항목**에 앱을 추가합니다.

### 첫 실행

배포 파일에는 ad-hoc 서명이 적용되어 있으며, Apple Developer ID 서명과 공증은 적용되어 있지 않습니다. macOS가 실행을 차단하면 [Apple의 신뢰하는 앱 실행 안내](https://support.apple.com/en-us/102445)를 따르거나 소스에서 직접 빌드할 수 있습니다.

### 다운로드 검증

같은 릴리스에서 `SHA256SUMS`를 다운로드해 ZIP과 같은 폴더에 저장한 후, 해당 폴더에서 실행합니다.

```sh
shasum -a 256 -c SHA256SUMS
```

## 사용 방법

메뉴 막대의 숫자는 **주간 사용 한도의 남은 비율**이며, 정확한 토큰 개수가 아닙니다. 아이콘을 클릭하면 상세 정보와 다음 메뉴를 사용할 수 있습니다.

| 메뉴 | 동작 |
| --- | --- |
| 사용량 보기… | 사용량 상세 창 열기 |
| 지금 새로고침 | 최신 사용량 조회 |
| Codex 열기 | 설치된 Codex 데스크톱 앱 실행 |
| 종료 | Codex Weekly 종료 |

초기화 시각은 Mac의 현지 시간대로 표시됩니다. 조회에 실패하거나 마지막 조회 값이 오래되면 비율 옆에 `?`가 표시됩니다. 조회된 초기화 시각이 지나면 새 조회가 성공할 때까지 이전 비율을 숨깁니다. 조회할 수 없는 값을 잔량 0으로 처리하지 않습니다.

### 남은 한도와 시간 비교

메뉴에는 주간 잔여 시간의 비율과 기간, 남은 한도와 시간의 비율 차이가 표시됩니다. 상세 창에서는 두 막대로 남은 한도와 시간을 나란히 비교할 수 있습니다. 시간은 달력상의 한 주가 아니라 **해당 계정의 다음 주간 초기화 시각**을 기준으로 계산합니다.

남은 시간 비율은 `초기화까지 남은 초 / 604,800 × 100`이며, 0~100% 범위로 제한합니다. **남은 한도 %에서 남은 시간 %를 뺀 차이**를 퍼센트포인트(`%p`)로 표시합니다. 양수이면 한 주 동안 균등하게 사용하는 기준보다 한도에 여유가 있고, 음수이면 그 기준보다 빠르게 사용한 상태입니다. 예를 들어 **한도 70%, 시간 40%가 남았다면 균등 사용 기준 대비 +30%p 여유**입니다. 이 값은 균등 사용 기준과의 비교이며, 앞으로의 사용량을 예측하거나 충분한 잔량을 보장하지는 않습니다.

초기화 시각이 없거나 이미 지났다면 비교를 제공하지 않습니다. 조회에 실패하거나 사용량이 오래된 값이면 최신 사용량을 확인할 때까지 사용 속도 판정을 보류합니다.

## 사용량 데이터

설치된 Codex 실행 파일의 [`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server)를 통해 한도를 조회합니다. 인증은 Codex가 처리하며, 이 앱에 별도 API 키를 설정할 필요가 없습니다. 조회 과정에서 모델 작업을 생성하거나 사용 한도 초기화 크레딧을 사용하지 않습니다.

일반 `codex` 사용 한도에서 10,080분 길이의 주간 구간을 읽습니다. 실행한 Codex 프로세스에서 사용할 수 있는 계정이 조회 대상입니다. 별도 `CODEX_HOME`이나 여러 Codex 설치본을 사용하는 경우 다른 Codex 세션과 계정이 다를 수 있습니다.

## 문제 해결

| 증상 | 확인 사항 |
| --- | --- |
| Codex를 찾을 수 없음 | 데스크톱 앱을 설치하거나 CLI를 `/opt/homebrew/bin/codex` 또는 `/usr/local/bin/codex`에 설치합니다. 사용자 지정 경로나 nvm에만 설치한 CLI는 자동으로 찾지 못합니다. |
| 주간 한도를 조회할 수 없음 | Codex 로그인 상태와 해당 계정의 주간 사용 한도 제공 여부를 확인합니다. |
| 비율 옆에 `?`가 표시됨 | 인터넷 연결을 확인하고 **지금 새로고침**을 선택합니다. |
| 다른 Codex 세션과 사용량이 다름 | 로컬 Codex 프로세스에서 사용하는 계정과 `CODEX_HOME`을 확인합니다. |

데스크톱 앱은 macOS 앱 등록 정보와 기본 `/Applications` 경로에서 찾습니다.

## 개발

**Xcode 16 이상** 또는 **Swift 6**이 포함된 Apple Command Line Tools가 필요합니다.

```sh
git clone https://github.com/dusagong/codex-weekly.git
cd codex-weekly
./scripts/package.sh
```

| 명령 | 동작 |
| --- | --- |
| `./scripts/test.sh` | 로컬 샘플로 모델 및 통신 테스트 실행 |
| `./scripts/build.sh` | 범용 앱 빌드 및 ad-hoc 서명 |
| `./scripts/package.sh` | 테스트, 앱 빌드, ZIP 및 체크섬 생성 |

앱은 `build/Codex Weekly.app`, 배포 파일은 `build/releases/`에 생성됩니다. 테스트는 Codex 계정이나 네트워크에 접근하지 않습니다.

앱 소스는 `src/`, 테스트 샘플은 `tests/`, 번들 정보는 `Info.plist`에 있습니다.

## 기여

버그 보고와 Pull Request를 환영합니다. [Issues](https://github.com/dusagong/codex-weekly/issues)에 macOS 버전, 프로세서, 앱 버전, 재현 방법을 포함해 주세요. 인증 파일, 토큰, 계정 로그는 제외해 주세요. 코드 변경을 제출하기 전에 `./scripts/test.sh`를 실행합니다.

## 라이선스

[MIT](LICENSE). Codex Weekly는 OpenAI 또는 Apple과 제휴하거나 공식 승인을 받은 제품이 아닌 독립 프로젝트입니다.
