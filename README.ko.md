# Codex Weekly

Mac 상단 메뉴 막대에 **Codex 주간 사용 한도의 남은 비율**을 표시하는 작은 앱입니다. Swift/AppKit으로 만들었으며, 작은 아이콘과 퍼센트 표시를 1분마다 자동 갱신합니다.

[English](README.md) · [ZIP 다운로드](https://github.com/dusagong/codex-weekly/releases/download/v1.1.0/Codex-Weekly-v1.1.0-macOS-universal.zip) · [최신 버전](https://github.com/dusagong/codex-weekly/releases/latest)

## 설치

1. ZIP 파일을 내려받고 더블클릭해 **Codex Weekly.app**의 압축을 풉니다.
2. 앱을 **응용 프로그램** 폴더로 옮긴 후 더블클릭합니다.
3. 화면 맨 위 오른쪽의 표시를 눌러 사용합니다. 첫 실행 때는 상세 창도 열리며, 창을 닫아도 메뉴 막대 표시는 유지됩니다.

Apple Silicon과 Intel 코드를 모두 포함한 범용 앱이며 **macOS 14 이상**을 대상으로 빌드합니다. 실제 실행은 Apple Silicon / macOS 26.4.1에서 확인했습니다. Intel 및 이전 macOS에서의 실제 실행은 아직 검증하지 않았습니다.

배포 파일은 로컬 서명만 적용되어 있고 **Apple Developer ID 서명·공증은 되어 있지 않습니다.** 첫 실행이 차단될 수 있습니다. 소스와 체크섬을 확인한 뒤 앱을 신뢰한다면 [Apple의 앱별 실행 안내](https://support.apple.com/en-us/102445)를 따르세요. 아래 방법으로 소스에서 직접 빌드해도 됩니다. Gatekeeper를 전체 해제할 필요는 없습니다.

로그인할 때 자동으로 실행하려면 **시스템 설정 → 일반 → 로그인 항목**에 앱을 추가하세요. 앱이 자동 시작을 임의로 설정하지는 않습니다.

## 필요한 환경

- 사용자 자신의 Mac에 **Codex 데스크톱 앱 또는 CLI**를 설치하고, 주간 사용량을 제공하는 자신의 ChatGPT 계정으로 로그인해야 합니다. 이 배포 파일에는 Codex 프로그램이나 계정이 포함되지 않습니다.
- 조회하려면 인터넷 연결이 필요합니다. API 키만 사용하는 계정에서는 주간 한도가 제공되지 않을 수 있습니다.

데스크톱 앱은 macOS 앱 등록 정보와 응용 프로그램 폴더에서 찾습니다. CLI는 `/opt/homebrew/bin/codex`와 `/usr/local/bin/codex`만 확인합니다. 사용자 지정 경로나 nvm에만 설치한 CLI는 자동으로 찾지 못합니다.

## 사용 방법

상단의 **79%** 같은 값은 정확한 남은 토큰 개수가 아닌 **주간 사용 한도의 남은 비율**입니다. 아이콘을 클릭하면 사용률, 초기화 시각, 마지막 조회 시간과 새로고침 메뉴를 볼 수 있습니다.

- **사용량 보기…**: 상세 창을 엽니다.
- **지금 새로고침**: 사용량을 다시 조회합니다.
- **종료**: 메뉴 막대 표시를 포함해 앱을 완전히 끕니다.

1분마다 자동 갱신하고 Mac이 잠자기에서 깨어나면 다시 조회합니다. 조회에 실패하거나 마지막 조회 값이 오래되면 이전 수치에 **?**를 붙입니다. 주간 초기화 시각이 지난 값은 새 조회가 성공할 때까지 숨깁니다. 초기화 시각은 Mac의 현지 시간대로 표시됩니다.

설치된 공식 Codex 프로그램을 실행해 [`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server)로 조회합니다. 기존 로그인은 Codex가 관리합니다. 배포 파일에 제작자의 계정은 포함되지 않으며, 이 앱은 인증 토큰을 복사하지 않습니다. 대화·모델 작업을 생성하거나 사용 한도 초기화 크레딧을 사용하지 않습니다. 일반 `codex` 한도 항목에서 10,080분짜리 주간 구간을 확인합니다.

여러 계정이나 별도 `CODEX_HOME`을 사용하는 경우, 이 앱이 실행한 Codex 프로그램의 계정이 다른 Codex 앱·CLI 세션과 다를 수 있습니다.

## 직접 빌드 및 테스트

**Xcode 16 이상** 또는 **Swift 6**이 포함된 Apple Command Line Tools를 설치한 후 실행합니다.

```sh
git clone https://github.com/dusagong/codex-weekly.git
cd codex-weekly
./scripts/package.sh
```

`package.sh`가 오프라인 테스트, 두 아키텍처 빌드, 로컬 서명 검증을 실행하고 다음 파일을 만듭니다.

- `build/Codex Weekly.app`
- `build/releases/Codex-Weekly-v1.1.0-macOS-universal.zip`
- `build/releases/SHA256SUMS`

`./scripts/test.sh`와 `./scripts/build.sh`를 따로 실행해도 됩니다. 모델·통신 테스트는 로컬 샘플만 사용하며 Codex 계정이나 네트워크에 접근하지 않습니다. 외부 Swift 패키지는 필요하지 않습니다. 앱 소스는 `src/`, 테스트는 `tests/`, 앱 정보는 `Info.plist`에 있습니다.

다운로드한 배포 파일을 검증하려면 ZIP과 `SHA256SUMS`를 같은 폴더에 놓고 그 폴더에서 `shasum -a 256 -c SHA256SUMS`를 실행하세요.

## 기여

문제나 개선 제안은 [Issues](https://github.com/dusagong/codex-weekly/issues)에 남겨 주세요. macOS 버전, 칩 종류, 앱 버전을 함께 적되 인증 파일이나 토큰, 계정 로그는 올리지 마세요. 코드를 기여할 때는 먼저 로컬 테스트를 실행해 주세요.

[MIT 라이선스](LICENSE)로 사용·수정·배포할 수 있습니다. Apple 또는 OpenAI의 공식 앱이 아닌 독립 프로젝트입니다.
