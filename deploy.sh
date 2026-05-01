#!/bin/bash
set -e

PROJECT="$(dirname "$0")/Orbit/Orbit.xcodeproj"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Orbit-gygwlfgqhvsoeugggtivyxdvcqtp/Build/Products/Debug/Orbit.app"
DEST="/Applications/Orbit.app"
LOG="$HOME/Library/Logs/Orbit.log"

# 빌드
echo "🔨 빌드 중..."
BUILD_LOG=$(mktemp)
if ! xcodebuild -project "$PROJECT" -scheme Orbit -configuration Debug build > "$BUILD_LOG" 2>&1; then
    echo "❌ 빌드 실패"
    grep "error:" "$BUILD_LOG" | head -10
    rm "$BUILD_LOG"
    exit 1
fi
rm "$BUILD_LOG"
echo "✅ 빌드 완료"

# 앱 종료
if pgrep -x Orbit > /dev/null 2>&1; then
    kill $(pgrep -x Orbit)
    sleep 0.5
fi

# /Applications에 복사 (기존 번들 삭제 후 교체 — cp -R은 기존 디렉토리에 병합되어 바이너리가 갱신 안 되는 버그 있음)
rm -rf "$DEST"
cp -R "$DERIVED" /Applications/

# 재실행
open "$DEST"
sleep 1

# 로그 확인
echo "--- 최근 로그 ---"
tail -5 "$LOG"
echo ""

# 권한 상태 확인
if tail -3 "$LOG" | grep -q "Accessibility 권한 없음"; then
    echo "⚠️  Accessibility 권한 필요"
    echo "   시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용 > Orbit 토글 ON"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
else
    echo "✅ 실행 완료"
fi
