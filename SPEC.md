# Orbit-mac PoC Spec

**Status:** ACTIVE — Approach A 구현 완료, dogfood 진행 중
**Last updated:** 2026-05-02
**Author:** yhbang@zimssa.com

---

## 0. 한 줄 요약

Mission Control 활성 상태에서 Tab/Shift+Tab/Enter로 창을 키보드만으로 선택하는 macOS 메뉴바 앱. PoC는 로컬 빌드 + Accessibility 권한만으로 dogfood 가능한 수준까지.

App Store 배포 없음 (개발자 계정 없음). 코드사이닝/notarization 불필요.

---

## 1. PoC가 검증해야 하는 것

이 PoC의 **단 하나의 목적**: "Mission Control 위에서 키보드만으로 창 선택 경험"이 기술적으로 만들 수 있고, 실제로 손이 키보드에서 안 떨어지는 흐름을 만드는지 확인.

검증 성공 기준:
- [x] Mission Control 활성 상태에서 Tab을 누르면 다음 창 thumbnail로 시각 포커스가 이동한다 (세션 2 확인)
- [x] Shift+Tab은 반대 방향 (구현 완료, 체감 테스트 진행 중)
- [x] Enter를 누르면 선택된 창으로 이동하고 Mission Control이 닫힌다 (세션 2 확인)
- [ ] 본인이 일주일 dogfood해보고 손이 마우스로 안 가는지 본인 감으로 평가 (진행 중)

**이 PoC가 답하지 않는 것:**
- 다른 사용자에게도 가치 있는가
- App Store에 올릴 수 있는가
- 키 바인딩 커스터마이징
- 멀티 모니터 / Spaces 간 이동
- fuzzy search, 앱별 grouping 같은 PRD의 future 항목

---

## 2. 핵심 기술 가정 (이게 깨지면 Approach 변경)

### Approach A — Cursor Warp (1순위)

핵심 아이디어: **시각 포커스를 우리가 그리지 않는다.** OS 커서를 다음 thumbnail 좌표로 텔레포트시키면 Apple이 자동으로 hover 효과를 그려줌. 우리는 키보드 → 커서 위치만 매핑.

```
Tab 누름
  → CGEventTap이 가로챔
  → 내부 인덱스 증가 (currentIndex = (currentIndex+1) % thumbnails.count)
  → CGWarpMouseCursorPosition으로 thumbnails[currentIndex].center로 점프
  → Apple이 자동으로 hover 시각효과 그림 (무료 시각 포커스)

Enter 누름
  → CGEventTap이 가로챔
  → 현재 커서 위치에 합성 click 이벤트 주입
  → Apple이 그 창을 활성화 + Mission Control 자동 종료
```

**검증 필수 가정:**
1. Mission Control 활성 중에 CGEventTap (`.cghidEventTap`, `.headInsertEventTap`)으로 키 이벤트를 가로챌 수 있다 — **✓ 확인** (세션 2)
2. Mission Control 활성 중에 thumbnail의 화면 좌표를 얻을 수 있다 — **✓ 확인** (세션 2, CGWindowList layer=0 frame이 thumbnail 좌표로 변환됨)
3. CGWarpMouseCursorPosition + 합성 클릭이 Mission Control 위에서 동작한다 — **✓ 확인** (세션 2, 듀얼 모니터 음수 좌표도 동작)

### Approach B — Self-Switcher (Approach A 좌표 획득 실패 시)

Mission Control 자체를 안 쓰고 자체 풀스크린 그리드 UI. AltTab의 expanded mode와 동일 구조.

- 단축키 (예: ⌥Space) → Orbit이 풀스크린 NSWindow 띄움
- `CGWindowListCopyWindowInfo`로 모든 창 목록 가져옴
- `CGWindowListCreateImage`로 각 창 썸네일 캡쳐
- 그리드로 직접 그림. Tab/Enter는 우리 NSWindow가 직접 받음 — CGEventTap 필요 없음
- Enter → 해당 창 raise, Orbit 윈도우 닫기

**장점:** 100% 안정. **단점:** "Mission Control 위에" 라는 PRD 영혼은 살짝 양보.

---

## 3. ~~다음 세션 첫 30분: 가정 검증~~ (완료)

세션 2에서 모든 가정 검증 완료. Approach A 채택 확정.

### 검증 절차

1. **Accessibility Inspector 준비** (Xcode에 포함됨)
   - Xcode 설치돼있으면 Spotlight에서 "Accessibility Inspector" 검색
   - 또는: `open /Applications/Xcode.app/Contents/Applications/Accessibility\ Inspector.app`

2. **Dock 프로세스의 AX 트리 살펴보기**
   - Inspector에서 Target → Dock.app 선택
   - Mission Control이 안 떠있을 때 vs 떠있을 때 children 비교
   - Mission Control 활성 시 추가되는 elements가 있는가? 그들이 thumbnail에 해당하는가?

3. **Mission Control이 Inspector를 가리는 문제 회피**
   - 외부 모니터가 있으면 Inspector를 거기 띄우면 됨
   - 아니면 macOS의 "screen recording" 기능으로 녹화해두고 사후 분석
   - 또는: 코드로 직접 AX 트래버스 결과를 파일에 덤프하는 5줄짜리 스크립트 작성 후 단축키로 실행

4. **결과 기록**
   - context.md에 발견 사항 적기
   - thumbnail이 AX로 보이면 → Approach A 진행
   - 안 보이거나 좌표가 일관성 없으면 → Approach B로 전환

### 보조 옵션 (AX가 안 될 때 PoC용 hack)

App Store 배포 안 할 거면 private API 후보:
- **CGSCopyWindowsWithOptionsAndTags** (private CGS) — Mission Control thumbnail 정보 노출 가능성. 검증 필요.
- **SkyLight framework** — 같은 영역. 함수 시그니처 reverse engineer 필요.
- **Screen capture + 이미지 grid 추정** — `CGDisplayCreateImage`로 화면 캡쳐 후 thumbnail 격자 추정. fragile하지만 dogfood용으로는 충분할 수 있음.

PoC 단계라 private API 써도 됨. 단 context.md에 "이건 빼야 함" 명시.

---

## 4. 구현 스캐폴딩

다음 세션에서 만들 것:

```
Orbit-mac/
├── Orbit-mac.xcodeproj/
├── Orbit-mac/
│   ├── OrbitApp.swift           # @main, NSApplicationDelegate
│   ├── AppDelegate.swift        # 메뉴바 아이콘, lifecycle
│   ├── Permissions.swift        # AXIsProcessTrusted 체크 + 권한 안내 다이얼로그
│   ├── KeyTap.swift             # CGEventTap 등록, Tab/Shift+Tab/Enter/ESC 콜백
│   ├── MissionControlDetector.swift  # Mission Control 활성 상태 감지
│   ├── ThumbnailLocator.swift   # AX로 thumbnail 좌표 쿼리 (Approach A의 핵심)
│   ├── CursorWarper.swift       # CGWarpMouseCursorPosition + 클릭 합성
│   └── Logger.swift             # ~/Library/Logs/Orbit-mac.log로 모든 이벤트 dump
├── README.md                     # 빌드/실행/Accessibility 권한 부여 가이드
└── .gitignore
```

**기술 스택:**
- Swift 5.9+, AppKit (SwiftUI 안 씀 — menubar app + low-level event 작업이라 AppKit이 자연스러움)
- 최소 macOS 타겟: 본인 macOS 버전 (PoC라 현재 버전만 지원)
- 외부 의존성 없음 (SPM도 사용 안 함)

**번들 / 실행 방식:**
- Xcode에서 Run으로 직접 실행하면 끝
- DMG는 PoC 단계에서 불필요 (본인만 씀)
- 메뉴바 아이콘으로 quit 가능, LSUIElement = YES (Dock 아이콘 안 뜨게)

---

## 5. 키 바인딩 (PoC 고정)

다음 세션 PoC에선 하드코딩. 커스터마이징은 v1.1.

| 키 | 동작 | Mission Control 활성 시에만 |
|----|------|---------------------------|
| Tab | 다음 thumbnail | ✓ |
| Shift+Tab | 이전 thumbnail | ✓ |
| Enter | 선택된 창으로 이동 | ✓ |
| ESC | Mission Control 닫기 (이벤트 통과) | ✓ |
| 그 외 모든 키 | 가로채지 않음 (시스템에 통과) | — |

**중요:** Mission Control이 비활성 상태에서는 CGEventTap이 아무것도 가로채면 안 됨. 가정 깨지면 시스템 전체 키 입력에 영향.

---

## 6. 초기 포커스 전략

Mission Control 진입 시 첫 포커스를 어디에 둘 것인가:

**PoC 기본:** 화면 좌상단(첫 번째) thumbnail.

이유: 단순. "현재 활성 앱" 또는 "최근 사용 창"을 thumbnail 좌표와 매칭하는 건 추가 검증 필요. v1.1로 미룸.

---

## 7. 명시적 비목표 (이번 PoC 범위 밖)

- App Store 배포, 코드사이닝, notarization
- 키 바인딩 커스터마이징 UI
- 멀티 모니터 thumbnail 정확 매핑
- Spaces 간 이동
- 앱별 grouping, fuzzy search
- 다른 사용자 dogfood (본인만)
- 시각 포커스를 PRD 4.2의 "outline + scale up + shadow"로 직접 그리는 것 (Apple hover에 의존)
- macOS 버전 호환성 매트릭스

---

## 8. Open Questions

1. ~~macOS 버전이 정확히 뭐고 거기서 Accessibility Inspector로 thumbnail이 보이는가~~ → macOS 15.6.1 Sequoia. CGWindowList 방식으로 해결 (AX Inspector 불필요)
2. ~~Approach A 실패 시 Approach B로 전환할지, 아니면 private API hack을 시도할지~~ → Approach A 성공, Approach B 불필요
3. PoC 성공 후 다음 단계: dmg 패키징? 다른 사람에게 배포 시도? (dogfood 완료 후 결정)

---

## 9. 현재 남은 작업

```
✓ Xcode 설치 확인
✓ macOS 버전 확인 (15.6.1 Sequoia)
✓ 가정 검증 (섹션 3)
✓ Approach A 결정 및 스캐폴딩 생성
✓ Tab/Enter 동작 확인
✓ Accessibility 권한 고정 (/Applications 운용 방식)

✓ 첫 Tab 시 index=0 자동 포커스 (currentIndex 초기값 -1로 수정)
✓ 선택 thumbnail 파란 테두리 오버레이 (SelectionOverlay.swift)
△ MC 내 데스크탑 전환 시 오버레이/index 리셋 (코드 작성 완료, 동작 미검증)
△ Spaces 바 레이아웃 변경 시 오버레이 위치 업데이트 (코드 작성 완료, 동작 미검증)
□ Shift+Tab 체감 테스트 (구현은 됨)
□ 일주일 dogfood 후 섹션 1 최종 평가
□ PoC 이후 방향 결정 (dmg 패키징, 배포 등)
```
