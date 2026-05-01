#!/bin/bash
set -e

DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Orbit-gygwlfgqhvsoeugggtivyxdvcqtp/Build/Products/Debug/Orbit.app"
DEST="/Applications/Orbit.app"
LOG="$HOME/Library/Logs/Orbit.log"

# 빌드 결과물 확인
if [ ! -d "$DERIVED" ]; then
    echo "❌ 빌드 결과물 없음: $DERIVED"
    echo "   Xcode에서 먼저 빌드(Cmd+B)하세요."
    exit 1
fi

# 앱 종료
if pgrep -x Orbit > /dev/null 2>&1; then
    kill $(pgrep -x Orbit)
    sleep 0.5
fi

# /Applications에 복사
cp -R "$DERIVED" "$DEST"

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
