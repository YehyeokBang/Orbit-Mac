# Orbit-mac 작업 일지

세션마다 시작/종료 시 엔트리 추가. 다음 세션이 컨텍스트 잃지 않게.

형식:
```
## YYYY-MM-DD HH:MM — 세션 N
**한 일:** ...
**발견:** ...
**열린 질문:** ...
**다음 세션:** ...
```

---

## 2026-05-02 — 세션 1 (kickoff, office-hours)

**한 일:**
- PRD 정리해서 office-hours 진행
- 기술적 premise 점검 — Mission Control hijack이 가능한지 검증
- Mission Control Plus(Fadel) 사례 조사: ⌘W/⌘M/⌘Q를 Mission Control 위에 얹는 게 가능함을 확인. CGEventTap + Accessibility 권한이 핵심.
- 사용자가 직접 테스트: macOS Mission Control 활성 상태에서 화살표키 위/아래/좌/우는 thumbnail focus 이동에 **동작 안 함**.
- 이로써 "Apple 기본 키보드 네비"에 의존하는 1차 가설 폐기. window thumbnail에는 native keyboard focus가 존재하지 않음.

**중요한 발견:**
- Mission Control Plus의 단축키들은 사실 **마우스 hover된 thumbnail**을 대상으로 동작. 자체 키보드 포커스를 만든 게 아님.
- 그래서 PRD 4.1(Tab으로 순회)을 만들려면 우리가 직접 "다음 thumbnail 어디인가"를 관리해야 함.

**결정한 것:**
- **Approach A (Cursor Warp)** 1순위로 시도: OS 커서를 Tab 입력에 맞춰 다음 thumbnail 좌표로 텔레포트. Apple의 자동 hover 효과를 시각 포커스로 재활용.
- **Approach B (Self-Switcher)** 폴백: Mission Control 안 쓰고 자체 풀스크린 그리드. AltTab expanded 스타일.
- 결정 분기점: "Mission Control 활성 중 thumbnail 화면 좌표를 AX로 얻을 수 있는가" — 다음 세션 첫 30분 검증.
- App Store 안 올릴 거니 PoC에선 private API (SkyLight/CGS) 사용 OK. 단 명시 필수.

**작성한 문서:**
- `SPEC.md` — PoC 스펙. 검증 절차, Approach A/B, 스캐폴딩 구조, 비목표 명시.
- `CLAUDE.md` — Claude 작업 규칙. 자동 수정 금지, 외부 의존성 금지, SwiftUI 금지 등.
- `context.md` — 이 파일.

**열린 질문 (다음 세션에서 답해야):**
1. 본인 macOS 버전이 정확히 뭔가 (검증 결과가 버전마다 다를 수 있음)
2. Xcode 설치돼있는가
3. Accessibility Inspector로 Dock 트리 들여다봤을 때 Mission Control thumbnail이 AX element로 노출되는가 — Approach A 성패 결정
4. 안 나오면 private API 시도할지 vs Approach B로 갈지

**다음 세션 시작 시:**
1. SPEC.md 섹션 9 체크리스트대로 진행
2. macOS / Xcode 버전 context.md에 기록
3. 30분 가정 검증 (SPEC.md 섹션 3) **먼저**. 코드 짜기 전.
4. 검증 결과에 따라 Approach A 스캐폴딩 또는 Approach B 전환

---

## 2026-05-02 — 세션 2 (검증 + 구현 시작)

**한 일:**
- CGWindowListCopyWindowInfo 딜레이 검증: MC 활성 시 layer=0 창 frame이 thumbnail 좌표로 변환됨 확인
- Approach A 채택 확정
- 스캐폴딩 생성: AppDelegate, KeyTap, ThumbnailLocator, CursorWarper, MissionControlDetector, Logger, Permissions
- main.swift 방식으로 entry point 수정 (@main + 스토리보드 없는 조합 문제 해결)
- App Sandbox 비활성화 (PoC라 불필요)
- Accessibility + 화면 기록 권한 부여 후 동작 확인

**검증 결과 — 성공:**
- Tab → 8개 thumbnail 감지 → 커서 warp ✓
- Enter → 합성 클릭 → 창 전환 + Mission Control 자동 종료 ✓
- 듀얼 모니터 음수 좌표도 정상 동작 ✓
- SPEC.md 섹션 1 성공 기준 달성

**발견:**
- AX inspector는 원래 창 좌표 반환 (thumbnail 좌표 아님) — CGWindowList가 정답이었음
- MissionControlDetector layer=18 방식: 정상 동작
- 첫 Tab이 index=1부터 시작됨 (index=0에 초기 포커스 없음) — 개선 가능

**다음 세션:**
- 첫 진입 시 index=0 자동 포커스 (현재는 첫 Tab이 index=1로 감)
- Shift+Tab 실제 체감 테스트
- 일주일 dogfood 후 SPEC.md 섹션 1 최종 평가

---

## 2026-05-02 — 세션 3 (권한 문제 해결 + 배포 절차 확립)

**한 일:**
- Accessibility 권한이 재시작마다 풀리는 원인 파악 및 해결
- /Applications/Orbit.app 설치 → 고정 바이너리 운용 방식 확립
- 배포 절차 CLAUDE.md에 문서화

**발견:**
- Xcode 빌드 시마다 바이너리 해시 변경 → macOS TCC가 새 앱으로 인식 → Accessibility 권한 초기화
- 해결책: /Applications에 복사해두고, 코드 변경 후 cp -R로 덮어쓰기
- `tccutil reset Accessibility dev.bang.Orbit` 으로 TCC 초기화 후 재등록하면 깔끔하게 해결됨

**확립된 배포 절차 (CLAUDE.md 빌드/실행 섹션에 상세 기록):**
1. Xcode 빌드 (Cmd+B)
2. `kill $(pgrep Orbit)` + `cp -R DerivedData/…/Orbit.app /Applications/`
3. `open /Applications/Orbit.app`
4. 로그에서 `[KeyTap] 시작됨` 확인

**다음 세션:**
- 첫 Tab 시 index=0 자동 포커스 (현재 index=1부터 시작)
- Shift+Tab 체감 테스트
- dogfood 이슈 수집

---

## 2026-05-02 — 세션 4 (오버레이 + 배포 자동화)

**한 일:**
- 불필요한 probe/ 스크립트 제거 (검증 완료, 역할 끝)
- GIT_CONVENTION.md 작성, CLAUDE.md 반영
- SPEC.md 현황 최신화 (Status ACTIVE, 체크박스 갱신)
- MIT 라이센스 추가 (qkddpgur318@gmail.com)
- 첫 Tab index=0 버그 수정 (currentIndex 초기값 -1)
- SelectionOverlay.swift 추가: Tab 이동 시 선택 thumbnail에 파란 테두리 표시
  - MissionControlDetector 폴링으로 MC 종료 시 자동 hide
  - NSScreen.screens.first로 멀티모니터 Y좌표 변환 수정
- deploy.sh 추가: `./deploy.sh` 한 번으로 빌드→배포→실행→로그 확인
- Xcode Personal Team 연결 → TeamIdentifier 부여 → TCC 권한 영구 유지

**발견:**
- tccutil reset 사용하면 안 됨 — TCC 날림. 권한 문제 시 시스템 설정 토글만.
- ad-hoc 서명은 빌드마다 해시 바뀌어 TCC 리셋. Personal Team 서명으로 해결.
- SelectionOverlay window level=maximumWindow로 Mission Control 위에 정상 표시 확인.
- NSScreen.main은 포커스 창 기준이라 멀티모니터에서 Y좌표 어긋남 → screens.first 사용.

**다음 세션:**
- Shift+Tab 체감 테스트
- 일주일 dogfood 후 SPEC.md 섹션 1 최종 평가
- PoC 이후 방향 결정 (README 작성, 배포 등)

---

## 2026-05-02 — 세션 5 (오버레이 버그 대응 + 배포 안정화)

**한 일:**
- 첫 Tab index=0 버그 수정 확인 (currentIndex=-1, 세션 4 반영)
- deploy.sh에 xcodebuild 빌드 단계 통합 (Cmd+B 없이 `./deploy.sh` 한 번에 끝)
- Xcode Personal Team 서명 → TeamIdentifier 부여 → TCC 권한 영구 유지 확인
- SelectionOverlay 버그 2가지 발견 및 수정 시도:
  1. MC 내 데스크탑 전환 시 오버레이 사라지고 index 유지 문제
  2. 마우스를 Spaces 바로 올리면 창이 아래로 내려가며 오버레이 좌표 어긋남
- mcWatcher 개선: thumbnail windowID 세트 변경 감지 → resetState(), 좌표 변경 → updateFrame()
- activeSpaceDidChangeNotification 추가 (MC 외부 스페이스 전환 대응)
- SelectionOverlay.updateFrame() 추가

**미해결 문제:**
- `clean build` 후 권한이 또 리셋됨 — Personal Team 서명인데도 TCC가 재인증 요구
  - deploy.sh의 일반 빌드(not clean)는 권한 유지됨. clean build가 문제.
  - deploy.sh에서 clean을 제거하면 됨 (현재 deploy.sh는 clean 없이 build만 함 — 정상)
  - 이번 세션에서 수동 clean build를 해서 권한이 한 번 더 풀린 것
- 데스크탑 전환 / Spaces 바 레이아웃 변경 수정 코드 작성했으나 권한 문제로 실제 동작 미검증

**발견:**
- xcodebuild + strings로 Swift 로그 문자열 검색 시 한글이 포함되면 검색 안 됨 (Swift 문자열 인코딩 차이)
- Swift 코드가 Orbit.debug.dylib에 컴파일됨 (main executable이 아닌 dylib). strings 검색 대상 다름.
- clean build는 TCC 권한 초기화 유발 가능 → deploy.sh는 clean 없이 사용할 것

**다음 세션 시작 시:**
1. 권한 재부여 1회 필요 (시스템 설정 → 손쉬운 사용 → Orbit ON)
2. MC 데스크탑 전환 시 `[KeyTap] 윈도우 목록 변경 → 리셋` 로그 확인
3. Spaces 바 레이아웃 변경 시 `updateFrame` 동작 확인
4. 동작 안 하면 mcWatcher 타이머 실행 여부 확인 (tick 로그 추가해서 디버그)

---

## 2026-05-02 — 세션 6 (mcWatcher 동작 검증)

**목표:**
- MC 내 데스크탑 전환 시 `[KeyTap] 윈도우 목록 변경 → 리셋` 로그 확인
- Spaces 바 레이아웃 변경 시 오버레이 위치 업데이트 확인

**세션 시작 시 코드 상태:**
- `KeyTap.swift`: mcWatcher(0.2s 폴링) + activeSpaceDidChangeNotification 모두 작성 완료
- `SelectionOverlay.swift`: updateFrame() 추가, 자체 pollTimer도 있음
- 세션 5에서 코드 작성했으나 권한 문제로 실제 동작 미검증

**한 일:**
- 데스크탑 전환 시 index 오류 수정 (`handleTab`: windowID 세트 달라지면 currentIndex 리셋)
- 데스크탑 전환 중 overlay 깜빡임 수정 (mcWatcher: currentIndex=-1이면 thumbnails만 갱신, resetState 생략)
- `activeSpaceDidChangeNotification` 제거: 실제 로그에서 전환 1회에 3번 연속 발화하여 overlay 숨김 버그 발생. mcWatcher가 이미 windowID 변화로 모든 케이스를 커버하므로 완전 제거

**발견:**
- `activeSpaceDidChangeNotification`은 한 번 전환에 최대 3회 발화 (타이밍 최대 ~1.5초 간격). mcWatcher 0.2s 폴링이 더 신뢰할 수 있음
- Spaces 바 레이아웃 변경(버벅임) → 폴링 특성상 200ms 이내 반영. PoC 단계에서는 허용 범위

**다음 세션:**
- Shift+Tab 체감 테스트
- 일주일 dogfood 후 SPEC.md 섹션 1 최종 평가


