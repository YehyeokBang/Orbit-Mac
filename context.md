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

**목표:** SPEC.md 섹션 3 가정 검증 → Approach A/B 결정 → 스캐폴딩 생성

**진행 중...**

---
