import Cocoa

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
// 창 하나(NSWindow) + NSView.draw()로 모든 배지를 한 번에 렌더링.
final class NumberOverlay {
    static let shared = NumberOverlay()
    private var window: NSWindow?

    // 윈도우 세트가 바뀔 때(MC 최초 활성 포함) 창을 새로 만든다.
    func show(thumbnails: [WindowThumbnail], order: [Int]) {
        guard NumberOverlaySettings.shared.isEnabled else { return }
        window?.orderOut(nil)
        window = makeWindow(thumbnails: thumbnails, order: order)
        window?.orderFrontRegardless()
    }

    // 레이아웃만 변경됐을 때 창 재생성 없이 뷰만 갱신. 숨긴 상태(window nil)면 아무것도 안 함.
    func update(thumbnails: [WindowThumbnail], order: [Int]) {
        guard NumberOverlaySettings.shared.isEnabled, window != nil else { return }
        guard let view = window?.contentView as? NumberOverlayView else { return }
        view.update(thumbnails: thumbnails, order: order)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }

    private func makeWindow(thumbnails: [WindowThumbnail], order: [Int]) -> NSWindow? {
        guard let screen = NSScreen.screens.first else { return nil }
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
            order: order
        )
        return win
    }
}

// 모든 thumbnail 배지를 한 NSView 안에서 그린다.
private final class NumberOverlayView: NSView {
    private var badges: [BadgeInfo] = []
    private let badgeSize: CGFloat = 34

    init(frame: NSRect, thumbnails: [WindowThumbnail], order: [Int]) {
        super.init(frame: frame)
        badges = makeBadges(thumbnails: thumbnails, order: order)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(thumbnails: [WindowThumbnail], order: [Int]) {
        badges = makeBadges(thumbnails: thumbnails, order: order)
        needsDisplay = true
    }

    // CG 좌표 → NSView(AppKit) 좌표 변환 후 배지 정보 생성
    private func makeBadges(thumbnails: [WindowThumbnail], order: [Int]) -> [BadgeInfo] {
        let screenH = bounds.height
        return order.prefix(9).enumerated().map { n, idx in
            let cg = thumbnails[idx].frame
            let appKitFrame = CGRect(x: cg.minX, y: screenH - cg.minY - cg.height,
                                    width: cg.width, height: cg.height)
            return BadgeInfo(number: n + 1, frame: appKitFrame)
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
