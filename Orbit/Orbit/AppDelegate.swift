import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let keyTap = KeyTap()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        keyTap.start()
        Logger.log("[App] Orbit 시작")
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyTap.stop()
        Logger.log("[App] Orbit 종료")
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)
        }
        let menu = NSMenu()
        menu.addItem(colorSubmenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "로그 보기", action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func colorSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "오버레이 색상", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let settings = OverlaySettings.shared
        for preset in settings.presets {
            let item = NSMenuItem(title: preset.name, action: #selector(selectColor(_:)), keyEquivalent: "")
            item.target = self
            item.image = colorDot(preset.color)
            if preset.name == settings.selectedName { item.state = .on }
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private func colorDot(_ color: NSColor) -> NSImage {
        let size = CGSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        OverlaySettings.shared.selectedName = sender.title
        // 체크마크 갱신
        if let submenu = sender.menu {
            for item in submenu.items { item.state = item == sender ? .on : .off }
        }
    }

    @objc private func openLog() {
        let logPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Orbit.log")
        NSWorkspace.shared.open(logPath)
    }
}
