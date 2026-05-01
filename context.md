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
