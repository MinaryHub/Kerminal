
### Changed
- **릴리스 페이지의 Windows 패키지 이름이 `kerminal-sideload.msix` 로 바뀌었습니다.**
  기능 변화는 없고 이름만 바뀝니다. 이전 이름(`kerminal.msix`)이 스토어 제출용
  패키지와 구분되지 않아 파트너 센터에 잘못 올려 세 번 반려됐습니다. 이제 두 패키지가
  이름으로 갈립니다 — 직접 설치는 `kerminal-sideload.msix`, 스토어 제출은
  `kerminal-store.msix`.
  - 인앱 업데이트가 참조하는 `latest.json` 의 Windows URL 도 함께 바뀌었으므로
    업데이트 확인은 그대로 동작합니다.

앱 코드 변경은 없습니다 — 1.1.0 과 동일한 바이너리에 패키징·문서만 정리한 릴리스입니다.

