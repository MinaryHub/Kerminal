# Kerminal

크로스플랫폼 SSH/터미널 클라이언트. Flutter 단일 코드베이스로 Windows / macOS / Linux / iOS / Android / Web을 지원합니다.

> 오픈소스([MIT 라이선스](LICENSE))입니다. 소스·릴리스·문의([Issues](https://github.com/MinaryHub/Kerminal/issues))·
> 정책 문서([PRIVACY.md](PRIVACY.md))가 모두 이 저장소에 있습니다. 배포 절차는 [DEPLOY.md](DEPLOY.md)를 보세요.

개발 계획은 [PLAN.md](PLAN.md), 배포 절차는 [DEPLOY.md](DEPLOY.md),
릴리스 전 손으로 확인할 항목은 [docs/MANUAL_TESTS.md](docs/MANUAL_TESTS.md)를 참고하세요.

## 다운로드 / 배포

최신 릴리스: **[Releases 페이지](https://github.com/MinaryHub/kerminal/releases/latest)** · [전체 릴리스](https://github.com/MinaryHub/kerminal/releases)

| 플랫폼 | 아티팩트 | 비고 |
|--------|----------|------|
| Windows | [Microsoft Store](https://apps.microsoft.com/detail/9P23N0L20CTR) · [`.msix`](https://github.com/MinaryHub/kerminal/releases/latest) | 스토어는 자동 업데이트·서명 완료. `.msix` 직접 설치 시 최초 1회 `kerminal-codesign.cer`를 **"신뢰할 수 있는 루트 인증 기관"**에 설치 ([DEPLOY.md](DEPLOY.md#windows-msix)) |
| macOS | [`.dmg`](https://github.com/MinaryHub/kerminal/releases/latest) | 열어서 Kerminal을 `Applications`로 드래그. 첫 실행은 **우클릭 → 열기**(Apple 서명·공증 전이라 Gatekeeper 경고) |
| Linux | [`.AppImage` / `.deb`](https://github.com/MinaryHub/kerminal/releases/latest) | |
| Android | [`.apk` / `.aab`](https://github.com/MinaryHub/kerminal/releases/latest) | Play Store: `.aab` |
| Web | `kerminal-web.tar.gz` | UI 전용 (브라우저 제약으로 직접 SSH 불가). Pages 미배포 — 예전 `minaryhub.github.io/kerminal` 링크는 설정된 적이 없어 404였습니다 |

> 릴리스 아티팩트는 `git tag vX.Y.Z` 푸시 시 [GitHub Actions](.github/workflows/release.yml)가
> 자동으로 빌드해 **드래프트 릴리스**에 첨부합니다. 앱은 [`latest.json`](DEPLOY.md#자동-업데이트-버전-인식--다운로드-안내)
> 매니페스트로 새 버전을 감지합니다.

## 후원

**현재 앱에서 숨겨져 있습니다.** MinaryHub 조직은 아직 후원을 받을 수 없고
(`hasSponsorsListing: false` — 조직 Sponsors 심사가 별도로 필요합니다), 개인 계정
페이지를 쓰면 조직으로 옮긴 이유가 무너지기 때문입니다.

조직 리스팅이 승인되면 [`lib/core/donation_config.dart`](lib/core/donation_config.dart)
의 `defaultValue` 를 `https://github.com/sponsors/MinaryHub` 로 바꾸면 됩니다.
대가는 붙이지 않습니다(정책 10.8.x: 혜택을 주면 Store IAP 의무).

## 기술 스택

| 영역 | 패키지 |
|------|--------|
| 프레임워크 | Flutter (Dart) |
| 상태관리 | `flutter_riverpod` |
| 라우팅 | `go_router` |
| SSH/SFTP | `dartssh2` |
| 터미널 | `xterm` |
| 로컬 DB | `drift` + `drift_flutter` (SQLite) |
| 보안 저장소 | `flutter_secure_storage` |

## 아키텍처

Clean Architecture 4레이어. **메타데이터는 DB, 시크릿(비밀번호·개인키)은 OS 보안 저장소**에 분리 저장합니다.

```
lib/
├─ core/          # theme, router 등 횡단 관심사
├─ presentation/  # 화면 (hosts, terminal)
├─ application/   # Riverpod providers / 유스케이스
├─ domain/        # entities, repository 인터페이스
└─ data/          # drift(local), secure vault, ssh service
```

## 개발 환경 설정

```bash
flutter pub get
dart run build_runner build   # drift 코드 생성 (*.g.dart)
flutter run                   # 실행 (기기/플랫폼 선택)
```

### 플랫폼별 요구사항

- **Windows 데스크톱:** 개발자 모드 활성화 필요 (`start ms-settings:developers`) — 플러그인 symlink 지원.
- **Android:** Android SDK cmdline-tools 설치 + `flutter doctor --android-licenses` 승인.
- **iOS / macOS:** macOS + Xcode 필요.
- **Web:** 추가 설정 없이 `flutter run -d chrome`.

## 검증

```bash
flutter analyze
flutter test
```

## 라이선스

MIT — [LICENSE](LICENSE)
