import Cocoa

// 숫자 키(1~9) 직접 이동 온/오프 설정 — 기본값 off
final class NumberKeySettings {
    static let shared = NumberKeySettings()
    private let key = "numberKeyEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// 숫자 오버레이 온/오프 설정
final class NumberOverlaySettings {
    static let shared = NumberOverlaySettings()
    private let key = "numberOverlayEnabled"

    var isEnabled: Bool {
        // 기본값 true — 키가 없으면 활성
        get { UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MC 활성 시 모든 thumbnail 위에 탭 순서 번호 배지를 표시하는 풀스크린 투명 오버레이.
// 멀티 모니터: 스크린마다 별도 NSWindow를 생성하고, 해당 스크린에 속한 배지만 렌더링.
// 번호는 전체 reading order 기준으로 연속 (스크린 간 분리 없음).
final class NumberOverlay {
    static let shared = NumberOverlay()
    private var windows: [(NSWindow, NSScreen)] = []

    func show(thumbnails: [WindowThumbnail], order: [Int]) {
        guard NumberOverlaySettings.shared.isEnabled else { return }
        hide()
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let win = makeWindow(screen: screen, primaryH: primaryH, thumbnails: thumbnails, order: order)
            windows.append((win, screen))
            win.orderFrontRegardless()
        }
    }

    // 레이아웃만 변경됐을 때 창 재생성 없이 뷰만 갱신. 숨긴 상태면 아무것도 안 함.
    func update(thumbnails: [WindowThumbnail], order: [Int]) {
        guard NumberOverlaySettings.shared.isEnabled, !windows.isEmpty else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        for (win, screen) in windows {
            (win.contentView as? NumberOverlayView)?.update(thumbnails: thumbnails, order: order, screen: screen, primaryH: primaryH)
        }
    }

    func hide() {
        windows.forEach { $0.0.orderOut(nil) }
        windows = []
    }

    private func makeWindow(screen: NSScreen, primaryH: CGFloat, thumbnails: [WindowThumbnail], order: [Int]) -> NSWindow {
        let win = NSWindow(
            contentRect: screen.frame,
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
        win.contentView = NumberOverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            thumbnails: thumbnails,
            order: order,
            screen: screen,
            primaryH: primaryH
        )
        return win
    }
}

// 한 스크린의 배지를 렌더링. 자신의 스크린에 속한 thumbnail만 그린다.
private final class NumberOverlayView: NSView {
    private var badges: [BadgeInfo] = []
    private let badgeSize: CGFloat = 34
    private let screen: NSScreen
    private let primaryH: CGFloat

    init(frame: NSRect, thumbnails: [WindowThumbnail], order: [Int], screen: NSScreen, primaryH: CGFloat) {
        self.screen = screen
        self.primaryH = primaryH
        super.init(frame: frame)
        badges = makeBadges(thumbnails: thumbnails, order: order)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(thumbnails: [WindowThumbnail], order: [Int], screen: NSScreen, primaryH: CGFloat) {
        badges = makeBadges(thumbnails: thumbnails, order: order)
        needsDisplay = true
    }

    // CG 좌표 → 이 스크린의 NSView 좌표로 변환.
    // 이 스크린에 속하지 않는 thumbnail은 제외(compactMap).
    // 번호는 전역 reading order 번호 그대로 유지.
    //
    // 좌표계:
    //   CG:     origin = 주 모니터 좌상단, Y↓
    //   AppKit: origin = 주 모니터 좌하단, Y↑
    //   View:   origin = 이 스크린의 좌하단, Y↑ (= AppKit - screen.frame.origin)
    //
    // CG rect(cx,cy,w,h) → View:
    //   viewX = cx - screen.frame.minX
    //   viewY = (primaryH - cy - h) - screen.frame.minY
    private func makeBadges(thumbnails: [WindowThumbnail], order: [Int]) -> [BadgeInfo] {
        return order.prefix(9).enumerated().compactMap { n, idx in
            let cg = thumbnails[idx].frame
            let globalAppKit = CGRect(
                x: cg.minX,
                y: primaryH - cg.minY - cg.height,
                width: cg.width,
                height: cg.height
            )
            guard screen.frame.intersects(globalAppKit) else { return nil }
            let viewFrame = CGRect(
                x: globalAppKit.minX - screen.frame.minX,
                y: globalAppKit.minY - screen.frame.minY,
                width: cg.width,
                height: cg.height
            )
            return BadgeInfo(number: n + 1, frame: viewFrame)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        badges.forEach(drawBadge)
    }

    private func drawBadge(_ badge: BadgeInfo) {
        let bx = badge.frame.minX + 10
        let by = badge.frame.maxY - badgeSize - 10
        let rect = CGRect(x: bx, y: by, width: badgeSize, height: badgeSize)

        // 그림자 — 어두운/밝은 썸네일 모두에서 배지가 떠 보이게
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = CGSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 4
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()

        // 흰 배경 원 — 어떤 썸네일 색상에서도 최대 대비
        let circle = NSBezierPath(ovalIn: rect)
        NSColor.white.withAlphaComponent(0.95).setFill()
        circle.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // 숫자 텍스트 — 검정
        let text = "\(badge.number)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.black,
        ]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: bx + (badgeSize - textSize.width) / 2,
                              y: by + (badgeSize - textSize.height) / 2),
                  withAttributes: attrs)
    }
}

private struct BadgeInfo {
    let number: Int
    let frame: CGRect
}
