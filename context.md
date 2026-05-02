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
- 오버레이 z-order 버그 계속 디버그 (아래 세션 7 참조)

---

## 2026-05-02 — 세션 7 (오버레이 z-order 미해결 디버그)

**목표:** 데스크탑 전환 후 Tab 시 오버레이가 보이지 않는 문제 원인 파악

**현재 코드 상태 (커밋 보류 중 디버그 빌드):**
- `SelectionOverlay.swift`: 디버그 모드 — 빨간 반투명 채움 + 6px 두꺼운 테두리, screens 로그 추가
- `SelectionOverlay.swift`: `show()` else 분기에서 `window.level` 매번 재지정 추가

**확인된 사실:**
- 스크린: 2560×1440 단일 모니터
- 모든 `appKit` 좌표가 화면 범위 안에 있음 (검증 완료)
- Tab은 잡힘 (`[KeyTap] Tab 가로챔` 로그 확인)
- `SelectionOverlay show` 로그도 매 Tab마다 정상 출력됨
- 그러나 **빨간 반투명 채움조차 육안으로 보이지 않음** → 얇은 테두리 문제가 아님
- `window.level` 매번 재지정해도 동일 → 단순 level 리셋 문제도 아님

**핵심 미스터리:**
- 전환 전(Desktop 3): 오버레이 정상 표시 ✓
- 전환 후(Desktop 4): `show()` 호출되고 좌표도 유효한데 완전히 안 보임 ✗
- Desktop 4로 전환 후 Desktop 3으로 돌아와도 안 보임 (스위치 이후 전체적으로 망가짐)

**시도했으나 효과 없었던 것:**
1. `activeSpaceDidChangeNotification` 제거 (notification 다중 발화 → overlay 숨김 버그 수정 — 이건 별개 문제로 해결됨)
2. `handleTab` race condition 차단 (index 문제 해결 — 이것도 별개)
3. `window.level` 매번 재지정 → 효과 없음
4. `deploy.sh` cp 버그 수정 (rm -rf 후 재복사) → 이전 배포들이 구버전 바이너리를 사용한 문제 해결

**의심 가는 원인 후보 (다음 세션 조사):**
1. `orderOut(nil)` 후 `orderFrontRegardless()` 시 macOS가 창을 잘못된 레이어에 배치하는 문제
   - 테스트: `orderOut` 대신 `setAlphaValue(0)` / `setAlphaValue(1)` 로 숨기기 (창을 실제로 없애지 않음)
2. `.canJoinAllSpaces` 동작이 space 전환 후 깨지는 문제
   - 테스트: `collectionBehavior`를 `show()` 마다 재설정
3. 창이 보이지 않는 레이어/window server context에 있는 것
   - 테스트: `window.isVisible`, `window.isOnActiveSpace` 로그 추가

**다음 세션 첫 시도:**
`orderOut` 대신 `setAlphaValue(0)` 로 숨기기 → 창을 화면에서 제거하지 않고 투명하게만 만들기
→ `SelectionOverlay.hide()` 에서 `window?.orderOut(nil)` → `window?.alphaValue = 0`
→ `SelectionOverlay.show()` 에서 `window?.orderFrontRegardless()` → `window?.alphaValue = 1`

**주의: 현재 SelectionOverlay.swift는 디버그 빌드 상태. 문제 해결 후 원복 필요:**
- OverlayView.draw(): 빨간 채움 → 원래 파란 테두리로
- show(): `screens:` 로그 제거

---

## 2026-05-02 — 세션 8 (z-order 버그 해결 + 로그 레벨 분리)

**한 일:**
- 세션 7의 z-order 버그(데스크탑 전환 후 오버레이 안 보임) 해결
- show()마다 NSWindow 새로 생성하도록 변경 — 망가진 window 인스턴스 재사용 회피
- `isReleasedWhenClosed = false` 설정, `close()` 호출 제거 — close()가 CGEventTap을 망가뜨리는 문제 해결
- 진단 보조: keyDown code/mcActive 로그, isVisible/isOnActiveSpace 로그, screens 로그 추가
- CGEventTap에 tapDisabledByTimeout/UserInput 마스크 추가 + 자동 재활성화 로직
- Logger에 debug 레벨 분리 추가 — `ORBIT_DEBUG=1` 환경변수일 때만 출력
- 고빈도/진단 로그(ThumbnailLocator, keyDown, screens, visible/onActiveSpace)를 `Logger.debug()`로 변경

**핵심 발견:**
- 데스크탑 전환 중 Tab 누르면 ThumbnailLocator가 mid-animation에 부분적 결과(예: 1개만) 잡고 그 좌표로 NSWindow 생성됨 → 이 window가 macOS window server 안에서 corrupt 상태가 되어 같은 인스턴스를 재사용하는 한 영원히 안 보임. 같은 NSWindow에서 setFrame/orderFront/alphaValue 무엇을 해도 복구 불가.
- `NSWindow.close()`는 default `isReleasedWhenClosed=true`라서 ARC와 이중 release 가능. 또한 borderless window를 close()하면 같은 프로세스의 CGEventTap이 keyDown 수신을 멈춰버림 (정확한 메커니즘 미규명, 재현으로 확인). `isReleasedWhenClosed=false`로 두고 orderOut + nil 할당만 하면 ARC가 안전하게 처리, event tap도 살아있음.
- CGEventTap이 `tapDisabledByTimeout`/`UserInput`로 disable되는 케이스는 이번 디버그 중 한 번도 발생 안 함 — 위 close() 문제가 진짜 원인이었음.

**검증 결과 (모든 케이스 통과):**
- 케이스 A: 현 데스크탑에서 Tab → 빨간 박스 ✓
- 케이스 B: MC 안에서 옆 데스크탑 전환 후 Tab → 빨간 박스 ✓
- 케이스 C: B 후 MC 다시 켜고 Tab → 빨간 박스 ✓
- A→ESC→A 반복 사이클도 정상 (이전엔 첫 사이클 후 keyDown 자체가 안 들어왔음)

**시각 정책 결정:**
- 빨간 채움 + 6px 테두리가 오히려 가시성 좋다는 사용자 피드백. 디버그 빌드 시각 그대로 유지.
- 차후 작업: Orbit 앱 켜면 설정창 띄워서 오버레이 색/스타일 사용자가 고를 수 있게 디벨롭

**앱 아이콘 작업:**
- 사용자가 생성한 `icon.png`(1254×1254 RGB, 모서리 검정)을 프로젝트 아이콘으로 적용
- Python PIL로 디자인 bbox 추출 후 정사각형 캔버스에 재배치 → 22.37% 반지름 squircle 마스크 적용 → 투명 모서리
- `sips`로 16/32/64/128/256/512/1024 사이즈별 PNG 생성, `Assets.xcassets/AppIcon.appiconset/Contents.json`에 슬롯 매핑
- 잔여 외곽 어둠은 원본 디자인의 의도된 림 효과로 판단 — 마스킹으론 제거 불가, 다음 버전은 풀블리드 캔버스로 재생성 예정 (프롬프트 v2 작성 완료, 사용자가 새 이미지 생성 중)

**다음 세션 / 후속 작업:**
- 사용자가 새 풀블리드 아이콘 생성해 오면 재적용 (현재 파이프라인 그대로 사용 가능)
- 일주일 dogfood
- SPEC.md 섹션 1 최종 평가
- README 작성, 배포 등

---

## 2026-05-02 17:24 — 세션 9 (메뉴바 아이콘 + 오버레이 색상 선택)

**한 일:**
- 메뉴바 아이콘을 `"⊙"` 텍스트 → SF Symbols `sparkle`로 변경
- `OverlaySettings` 클래스 추가 — 7가지 프리셋 색상(빨강/파랑/초록/노랑/보라/검정/흰색), `UserDefaults` 저장
- `OverlayView`에 색상 주입 — 채움/테두리 모두 선택 색상으로 렌더링
- AppDelegate 메뉴에 "오버레이 색상 ▶" 서브메뉴 추가 — 색상 원 아이콘 + 체크마크 표시

**결정한 것:**
- NSColorPanel 팔레트 대신 프리셋 7색으로 결정 — PoC 단계에서 메뉴바 앱 UX에 적합
- SF Symbols는 App Store/로컬 빌드 모두 사용 가능, 다크/라이트 모드 자동 대응

**다음 세션 / 후속 작업:**
- 사용자가 새 풀블리드 아이콘 생성해 오면 재적용
- 일주일 dogfood 후 SPEC.md 섹션 1 최종 평가
- README 작성, 배포 등

---

## 2026-05-02 17:35 — 세션 10 (화살표키 네비게이션)

**한 일:**
- MC 안에서 ←/→ 화살표키로 thumbnail 이동 추가
- Control+화살표는 Spaces 이동 그대로 통과 (flags.maskControl 분기)
- 기존 handleTab(reverse:) 재사용 — index 설계 변경 없음

**다음 세션 / 후속 작업:**
- 핵심 사용성 완성 단계 — dogfood 후 방향 결정
- 후보: 로그인 시 자동 실행, README/배포, 아이콘 교체, ESC 동작 개선
