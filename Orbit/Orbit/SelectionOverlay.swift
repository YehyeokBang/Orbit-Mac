import Cocoa

final class OverlaySettings {
    static let shared = OverlaySettings()
    private let key = "overlayColor"

    let presets: [(name: String, color: NSColor)] = [
        ("빨강", .red),
        ("파랑", .systemBlue),
        ("초록", .systemGreen),
        ("노랑", .systemYellow),
        ("보라", .systemPurple),
        ("검정", .black),
        ("흰색", .white),
    ]

    var selectedName: String {
        get { UserDefaults.standard.string(forKey: key) ?? "빨강" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var color: NSColor {
        presets.first { $0.name == selectedName }?.color ?? .red
    }
}

// Tab 이동 시 선택된 thumbnail 위에 테두리 오버레이를 그림.
// CGWindowList 좌표(좌상단 origin) → AppKit 좌표(좌하단 origin) 변환 필요.
final class SelectionOverlay {
    private var window: NSWindow?
    private var pollTimer: DispatchSourceTimer?

    func show(frame cgFrame: CGRect, appName: String = "") {
        let appKitFrame = toAppKit(cgFrame)

        // 매번 창 새로 만듦 — MC 내 space 전환 중에 만들어진 window가 망가지는 케이스 회피
        window?.orderOut(nil)

        let win = NSWindow(
            contentRect: appKitFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        win.contentView = OverlayView(frame: NSRect(origin: .zero, size: appKitFrame.size), color: OverlaySettings.shared.color, appName: appName)
        window = win

        window?.orderFrontRegardless()
        Logger.debug("[SelectionOverlay] visible=\(window?.isVisible ?? false) onActiveSpace=\(window?.isOnActiveSpace ?? false)")
        let screensInfo = NSScreen.screens.map { "(\(Int($0.frame.width))×\(Int($0.frame.height)) at \(Int($0.frame.origin.x)),\(Int($0.frame.origin.y)))" }.joined(separator: " | ")
        Logger.debug("[SelectionOverlay] screens: \(screensInfo)")
        Logger.log("[SelectionOverlay] show at appKit=(\(Int(appKitFrame.minX)),\(Int(appKitFrame.minY))) \(Int(appKitFrame.width))×\(Int(appKitFrame.height))")
        startPolling()
    }

    func hide() {
        stopPolling()
        window?.orderOut(nil)
        window = nil
        Logger.log("[SelectionOverlay] hide")
    }

    // 오버레이 위치만 업데이트 (타이머 재시작 없음) — 레이아웃 변경 시 사용
    func updateFrame(_ cgFrame: CGRect) {
        guard let window else { return }
        let appKitFrame = toAppKit(cgFrame)
        window.contentView?.setFrameSize(appKitFrame.size)
        window.contentView?.needsDisplay = true
        window.setFrame(appKitFrame, display: true)
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
    private let color: NSColor
    private let appName: String

    init(frame: NSRect, color: NSColor, appName: String) {
        self.color = color
        self.appName = appName
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // 배경 채움 + 테두리
        color.withAlphaComponent(0.3).setFill()
        bounds.fill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6)
        path.lineWidth = 6
        color.withAlphaComponent(0.9).setStroke()
        path.stroke()

        guard !appName.isEmpty else { return }

        // 앱 이름 pill — 하단 중앙
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 3
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white,
            .shadow: shadow,
        ]
        let textSize = (appName as NSString).size(withAttributes: attrs)
        let pillPadding: CGFloat = 10
        let pillH: CGFloat = textSize.height + 8
        let pillW = textSize.width + pillPadding * 2
        let pillX = (bounds.width - pillW) / 2
        let pillY: CGFloat = 10

        let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
        NSColor.black.withAlphaComponent(0.6).setFill()
        pillPath.fill()

        let textX = pillX + pillPadding
        let textY = pillY + (pillH - textSize.height) / 2
        (appName as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attrs)
    }
}
