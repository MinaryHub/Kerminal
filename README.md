# Kerminal

크로스플랫폼 SSH / 터미널 클라이언트. Windows · macOS · Linux · Android 를 지원합니다.

탭으로 여러 서버에 동시에 접속하고, SFTP 로 파일을 주고받고, 2단계 인증(OTP) 서버에
접속할 수 있습니다. 자격증명은 OS 보안 저장소에 보관하며, 계정을 쓰는 경우 서버 목록은
**종단 간 암호화**되어 동기화됩니다.

> ⚠️ **이 저장소는 더 이상 사용하지 않습니다.** 소스·릴리스·문의·정책 문서는 모두
> [`MinaryHub/Kerminal`](https://github.com/MinaryHub/Kerminal)(MIT 오픈소스)에 있습니다.
> 새 버전은 [Releases](https://github.com/MinaryHub/Kerminal/releases)에서, 문의는 [Issues](https://github.com/MinaryHub/Kerminal/issues)에 남겨 주세요.

## 다운로드

최신 버전: **[Releases 페이지](https://github.com/MinaryHub/kerminal/releases/latest)**

| 플랫폼 | 받을 파일 | 설치 |
|--------|-----------|------|
| Windows | [Microsoft Store](https://apps.microsoft.com/detail/9P23N0L20CTR) | 자동 업데이트·서명 완료. **권장** |
| Windows (직접 설치) | `kerminal-sideload.msix` | 먼저 `kerminal-codesign.cer` 를 **"신뢰할 수 있는 루트 인증 기관"** 에 설치한 뒤 msix 실행 |
| macOS | `kerminal-macos.dmg` | 열어서 Kerminal 을 `Applications` 로 드래그. 첫 실행은 **우클릭 → 열기** (Apple 공증 전이라 Gatekeeper 경고) |
| Linux | `kerminal-linux-x64.tar.gz` | 풀어서 실행 |
| Android | `kerminal.apk` | 설치 시 "출처를 알 수 없는 앱" 허용 필요 |

앱은 실행 중 새 버전이 나오면 알려줍니다 — 버전 매니페스트
([`latest.json`](https://github.com/MinaryHub/kerminal/releases/latest/download/latest.json))
하나만 HTTPS 로 받아 현재 버전과 비교합니다.

## 문의 · 버그 신고

- 앱 안에서: **설정 → Support → Contact us**
- 또는 [Issues](https://github.com/MinaryHub/kerminal/issues)

## 개인정보처리방침

[PRIVACY.md](PRIVACY.md) 를 보세요. 요약하면 — 서버 접속 정보와 자격증명은 기본적으로
**기기 안에만** 있습니다. 계정을 만들어 동기화를 켠 경우에만 서버로 올라가며, 그때도
기기에서 암호화한 뒤 전송하므로 서버는 내용을 볼 수 없습니다. 광고·추적기는 없습니다.

## 라이선스

MIT — [LICENSE](LICENSE) 참조. 소스는 [`MinaryHub/Kerminal`](https://github.com/MinaryHub/Kerminal).
