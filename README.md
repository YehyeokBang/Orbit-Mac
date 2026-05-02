# Orbit

**Mission Control에 키보드 네비게이션을 추가하는 macOS 유틸리티**

macOS Mission Control은 열린 창을 한눈에 볼 수 있지만, 원하는 창으로 이동하려면 항상 마우스를 써야 합니다. Orbit을 사용하면 Mission Control 위에서 키보드만으로 창을 탐색하고 전환할 수 있습니다.

![demo](orbit-demo.mp4)

---

## 기능

| 키 | 동작 |
|---|---|
| `Tab` | 다음 창으로 이동 (읽기 순서) |
| `Shift+Tab` | 이전 창으로 이동 |
| `←` `→` `↑` `↓` | 방향 기반 이동 (가장 가까운 창) |
| `Enter` | 선택한 창으로 전환 |
| `Cmd+Delete` | 선택한 앱 종료 |

- **2D 스마트 네비게이션** — 화살표 방향으로 가장 가까운 창을 우선 선택. 가장자리에서 정지.
- **선택 오버레이** — 현재 포커스된 창에 컬러 테두리와 앱 이름 표시
- **오버레이 색상 선택** — 메뉴바 아이콘 클릭 → 7가지 프리셋 (빨강/파랑/초록/노랑/보라/검정/흰색)
- **로그인 시 자동 실행**

---

## 설치

### 빌드된 앱 다운로드 (권장)

1. [Releases](../../releases) 에서 최신 `Orbit.zip` 다운로드
2. 압축 해제 후 `Orbit.app`을 `/Applications`로 드래그
3. 처음 실행 시 Gatekeeper 경고 → **우클릭 → 열기**로 실행
4. 시스템 설정 → 개인정보 보호 및 보안 → **손쉬운 사용**에서 Orbit 허용

### 소스에서 빌드

```bash
git clone https://github.com/YehyeokBang/Orbit-Mac.git
cd Orbit-Mac
open Orbit/Orbit.xcodeproj
```

Xcode에서 빌드 후 `Orbit.app`을 `/Applications`로 복사합니다.

---

## 요구사항

- macOS 15.2 이상

### 필요한 권한

| 권한 | 위치 | 이유 |
|---|---|---|
| **손쉬운 사용** | 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 | Mission Control 활성 중 키 입력(Tab, 화살표 등)을 감지하기 위해 필요 |

> Orbit은 키 입력을 Mission Control이 활성화된 동안에만 가로챕니다. 수집하거나 전송하는 데이터는 없습니다.

---

## 버전

[GitHub Releases](../../releases)에서 관리합니다.

- `v0.x.x` — 기능 개발 / 검증 단계
- 변경 내역은 각 Release 노트에 기록

---

## 라이선스

MIT © [YehyeokBang](https://github.com/YehyeokBang)
