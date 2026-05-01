# Git 커밋 컨벤션

## 형식

```
<타입>: <작업 내용 한글로>

- 어떤 것을 무엇으로 바꿈
- 어떤 것을 무엇으로 바꿈
```

본문은 변경이 명확한 경우 생략 가능.

## 타입

| 타입 | 사용 상황 |
|------|----------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서 변경 (CLAUDE.md, SPEC.md, context.md 등) |
| `refactor` | 동작 변경 없는 코드 정리 |
| `chore` | 빌드 설정, .gitignore 등 기타 |

## 규칙

- 작업 단위는 롤백 가능한 단위를 지양함 (PoC라 WIP 커밋 OK)
- 브랜치는 `main` 단일 사용 (다른 브랜치 계획 없음)
- push 기준: `origin main`

## 예시

```
feat: Mission Control 활성 감지 로직 추가

- CGWindowList layer=18 방식으로 MC 활성 여부 판단
- KeyTap에서 MC 비활성 시 이벤트 통과하도록 가드 추가
```

```
fix: 첫 Tab 시 index=1부터 시작되는 문제 수정
```

```
docs: 배포 절차 CLAUDE.md에 추가
```
