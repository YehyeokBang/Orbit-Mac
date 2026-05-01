import Cocoa

// CGEventTap으로 Tab/Shift+Tab/Enter/ESC를 가로챔.
// Mission Control 비활성 상태에서는 아무것도 가로채지 않음.
final class KeyTap {
    private var tap: CFMachPort?
    private var currentIndex: Int = -1
    private var thumbnails: [WindowThumbnail] = []
    private let overlay = SelectionOverlay()

    func start() {
        guard AXIsProcessTrusted() else {
            Logger.log("[KeyTap] Accessibility 권한 없음 — 시스템 설정 > 손쉬운 사용에서 Orbit 허용 후 재시작")
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                let me = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            Logger.log("[KeyTap] CGEvent.tapCreate 실패 — Accessibility 권한 확인 필요")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Logger.log("[KeyTap] 시작됨")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        Logger.log("[KeyTap] 중지됨")
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard MissionControlDetector.isActive() else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Tab = 48, Enter = 36, ESC = 53
        switch keyCode {
        case 48: // Tab
            let isShift = flags.contains(.maskShift)
            Logger.log("[KeyTap] \(isShift ? "Shift+Tab" : "Tab") 가로챔")
            handleTab(reverse: isShift)
            return nil  // 이벤트 삼킴

        case 36: // Enter
            Logger.log("[KeyTap] Enter 가로챔")
            overlay.hide()
            CursorWarper.clickAtCurrentPosition()
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleTab(reverse: Bool) {
        thumbnails = ThumbnailLocator.fetchThumbnails()
        guard !thumbnails.isEmpty else {
            Logger.log("[KeyTap] thumbnail 없음 — Tab 무시")
            return
        }

        if reverse {
            currentIndex = (currentIndex - 1 + thumbnails.count) % thumbnails.count
        } else {
            currentIndex = (currentIndex + 1) % thumbnails.count
        }

        let target = thumbnails[currentIndex]
        Logger.log("[KeyTap] → index=\(currentIndex) \(target.ownerName) center=(\(Int(target.center.x)), \(Int(target.center.y)))")
        CursorWarper.warp(to: target.center)
        overlay.show(frame: target.frame)
    }
}
