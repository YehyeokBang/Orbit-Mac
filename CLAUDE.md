# CLAUDE.md — Orbit-mac 작업 규칙

이 파일은 Claude가 이 프로젝트에서 따라야 할 규칙입니다. 사용자가 직접 관리.

---

## 프로젝트 한 줄 요약

macOS Mission Control 위 키보드 네비게이션. PoC 단계, 본인 dogfood용. App Store 안 올림.

상세는 `SPEC.md`. 작업 일지는 `context.md`.

---

## 작업 시작 시 항상

1. `SPEC.md` 읽고 현재 PoC 범위 확인
2. `context.md` 마지막 엔트리 읽고 직전 세션 상태 파악
3. 작업 시작/종료 시 `context.md`에 엔트리 추가

---

## 코드 / 결정 규칙

### 하지 말 것

- **자동으로 코드 수정하지 말 것.** 리뷰는 Claude, 수정은 사용자가 직접. 발견한 문제는 파일:라인 번호로 짚어주고 손은 대지 말기. (개인 워크플로우 원칙 — `~/.claude/projects/-Users-yehyeok/memory/feedback_review_ownership.md` 참조)
- **PRD/SPEC 범위 임의 확장 금지.** "이러면 좋을 것 같아서"로 기능 추가하지 말기. 비목표는 SPEC.md 섹션 7에 명시돼있음.
- **App Store 호환성 신경 쓰지 말 것.** 코드사이닝, sandbox, entitlements 같은 거 PoC 단계에선 무시. 필요하면 명시적으로 비활성화.
- **외부 의존성 추가하지 말 것.** SPM 패키지, CocoaPods, Carthage 다 안 씀. AppKit + 표준 라이브러리만.
- **SwiftUI 사용하지 말 것.** menubar app + low-level event 작업이라 AppKit이 자연스러움. SwiftUI는 PoC 끝난 후 검토.
- **Private API 쓸 때는 반드시 명시.** SkyLight, CGS 함수 등 사용 시 `// PRIVATE_API: <함수명>` 주석 필수. context.md에 "이건 빼야 함" 기록.
- **시스템 전체 키 입력에 영향 주는 코드 신중하게.** CGEventTap이 Mission Control 비활성 상태에서도 키를 먹으면 시스템 망가짐. 가드 로직 검증 후 작성.
- **destructive shell command 그냥 실행 금지.** `rm -rf`, `git reset --hard`, `git push --force` 등은 사용자에게 확인 후. (auto mode여도 SPEC 6번 규칙)

### 할 것

- **Spec/문서 먼저, 코드 나중.** SPEC 어긋난 코드 짜기 전에 SPEC 업데이트 제안.
- **검증 가능한 단위로 쪼개기.** "Tab 가로채기 1차 검증" → "thumbnail 좌표 쿼리" → "커서 워프" 순서. 각 단계 끝나면 콘솔 로그 확인.
- **로깅 적극.** `Logger.swift`에 모든 이벤트 dump. PoC 단계라 verbose가 미덕.
- **Approach A 실패 시 즉시 Approach B 전환 제안.** 30분 검증 결과가 음성이면 사용자에게 보고하고 결정 받기.
- **사용자가 백엔드(Spring/Java) 배경.** Swift/AppKit 처음일 가능성 높음. 보일러플레이트 같은 건 자세히, "이건 Java로 치면 X" 같은 비유 OK.

---

## 빌드 / 실행

```
□ Xcode 버전: 16.2
□ macOS 타겟: 15.6.1 (Sequoia)
□ 빌드 명령: Xcode에서 Cmd+B (또는 Cmd+R)
□ 프로젝트 경로: Orbit/Orbit/Orbit.xcodeproj
```

### 코드 변경 후 배포 절차 (중요)

Xcode로 빌드하면 바이너리 해시가 바뀌어 Accessibility 권한이 초기화됨.
/Applications에 설치한 고정 바이너리를 사용해 이 문제를 우회.

**코드 변경 → 실행까지 순서:**

1. Xcode에서 빌드 (Cmd+B)
2. 기존 앱 종료: 메뉴바 Orbit `⊙` → 종료 (또는 `kill $(pgrep Orbit)`)
3. /Applications에 덮어쓰기:
   ```
   cp -R "$HOME/Library/Developer/Xcode/DerivedData/Orbit-gygwlfgqhvsoeugggtivyxdvcqtp/Build/Products/Debug/Orbit.app" /Applications/
   ```
4. 재실행: `open /Applications/Orbit.app`
5. 로그 확인: `tail -f ~/Library/Logs/Orbit.log` → `[KeyTap] 시작됨` 확인

**권한 문제가 생기면 (AXIsProcessTrusted 실패 시):**
```
tccutil reset Accessibility dev.bang.Orbit
open /Applications/Orbit.app
```
→ 시스템 설정 → 손쉬운 사용에서 Orbit 토글 ON

**참고:**
- Bundle ID: `dev.bang.Orbit`
- DerivedData 경로 해시: `Orbit-gygwlfgqhvsoeugggtivyxdvcqtp` (Xcode 재설치 시 바뀔 수 있음)
- /Applications/Orbit.app을 기준으로 권한이 고정됨 — DerivedData 버전은 실행하지 말 것

---

## 커밋 / 브랜치

상세 컨벤션은 `GIT_CONVENTION.md` 참조.

- 현재 브랜치: `main` (다른 브랜치 계획 없음)
- 커밋 메시지: `feat: 한글 설명` 형식. 본문은 `- 어떤 것을 무엇으로 바꿈` 형식.
- WIP 커밋 OK. PoC라 깔끔함보다 흐름 보존이 중요.

---

## 작업 일지

`context.md`를 매 세션 시작/종료 시 업데이트. 형식:

```
## YYYY-MM-DD HH:MM — 세션 N
**한 일:**
- ...
**발견:**
- ...
**다음 세션:**
- ...
```

---

## 참고 — 디자인 doc 백업

이 세션의 office-hours 결과물(premise 정리, approach A/B 비교, 검증 절차)은 `~/.gstack/projects/Orbit/`에도 저장됨. 다음 세션에서 컨텍스트 잃었으면 거기 참고.
