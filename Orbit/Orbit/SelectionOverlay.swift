import Cocoa

// Tab 이동 시 선택된 thumbnail 위에 테두리 오버레이를 그림.
// CGWindowList 좌표(좌상단 origin) → AppKit 좌표(좌하단 origin) 변환 필요.
final class SelectionOverlay {
    private var window: NSWindow?
    private var pollTimer: DispatchSourceTimer?

    func show(frame cgFrame: CGRect) {
        let appKitFrame = toAppKit(cgFrame)

        if window == nil {
            let win = NSWindow(
                contentRect: appKitFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            // Mission Control 위에 올라오려면 최대한 높은 레벨 필요
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
            win.contentView = OverlayView(frame: NSRect(origin: .zero, size: appKitFrame.size))
            window = win
        } else {
            window?.contentView?.setFrameSize(appKitFrame.size)
            window?.contentView?.needsDisplay = true
            window?.setFrame(appKitFrame, display: true)
        }

        window?.orderFrontRegardless()
        Logger.log("[SelectionOverlay] show at appKit=(\(Int(appKitFrame.minX)),\(Int(appKitFrame.minY))) \(Int(appKitFrame.width))×\(Int(appKitFrame.height))")
        startPolling()
    }

    func hide() {
        stopPolling()
        window?.orderOut(nil)
        Logger.log("[SelectionOverlay] hide")
    }

    // Mission Control이 닫히면 오버레이 자동 제거
    private func startPolling() {
        stopPolling()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
        timer.setEventHandler { [weak self] in
            if !MissionControlDetector.isActive() {
                self?.hide()
            }
        }
        timer.resume()
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    // CG 좌표(좌상단 origin) → AppKit 좌표(좌하단 origin).
    // NSScreen.screens.first = 메뉴바 스크린 = CG 좌표계 기준점. main은 포커스 창 기준이라 멀티모니터에서 틀릴 수 있음.
    private func toAppKit(_ rect: CGRect) -> CGRect {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

private class OverlayView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 3
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: 6, yRadius: 6)
        path.lineWidth = 3
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
}
