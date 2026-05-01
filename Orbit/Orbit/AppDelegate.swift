import Cocoa

@main
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
            button.title = "⊙"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "로그 보기", action: #selector(openLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openLog() {
        let logPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Orbit.log")
        NSWorkspace.shared.open(logPath)
    }
}
