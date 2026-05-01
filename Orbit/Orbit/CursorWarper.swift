import Cocoa

enum CursorWarper {
    // CGPoint는 CoreGraphics 좌표 (좌상단 origin). CGWarpMouseCursorPosition도 동일 좌표계.
    static func warp(to point: CGPoint) {
        Logger.log("[CursorWarper] warp to (\(Int(point.x)), \(Int(point.y)))")
        CGWarpMouseCursorPosition(point)
        // 커서 이동 후 시스템이 hover 효과를 그릴 시간을 줌
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    // 현재 커서 위치에 left click 합성 주입. Enter 키 처리 시 사용.
    static func clickAtCurrentPosition() {
        let pos = NSEvent.mouseLocation
        // NSEvent는 좌하단 origin → CoreGraphics 좌표로 변환
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPos = CGPoint(x: pos.x, y: screenHeight - pos.y)

        Logger.log("[CursorWarper] click at (\(Int(cgPos.x)), \(Int(cgPos.y)))")

        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: cgPos, mouseButton: .left)
        let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,   mouseCursorPosition: cgPos, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
