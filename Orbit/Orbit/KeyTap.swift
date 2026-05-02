import Cocoa

// CGEventTap으로 Tab/Shift+Tab/Enter/ESC를 가로챔.
// Mission Control 비활성 상태에서는 아무것도 가로채지 않음.
final class KeyTap {
    private var tap: CFMachPort?
    private var currentIndex: Int = -1
    private var thumbnails: [WindowThumbnail] = []
    private let overlay = SelectionOverlay()
    private var mcWasActive: Bool = false
    private var mcWatcher: DispatchSourceTimer?

    func start() {
        guard AXIsProcessTrusted() else {
            Logger.log("[KeyTap] Accessibility 권한 없음 — 시스템 설정 > 손쉬운 사용에서 Orbit 허용 후 재시작")
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
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
        startMCWatcher()
        Logger.log("[KeyTap] 시작됨")
    }

    // MC 상태 + thumbnail 변화를 주기적으로 감시
    // - MC 종료 시 → resetState()
    // - MC 활성 중 windowID 세트 변경 → 데스크탑 전환이므로 resetState()
    // - MC 활성 중 좌표만 변경 → 레이아웃 변경(Spaces 바 펼침 등)이므로 오버레이 위치만 업데이트
    private func startMCWatcher() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let isActive = MissionControlDetector.isActive()

            if self.mcWasActive && !isActive {
                self.resetState()
                Logger.log("[KeyTap] MC 종료 감지 → 리셋")
            } else if isActive && !self.thumbnails.isEmpty {
                let updated = ThumbnailLocator.fetchThumbnails()
                let oldIDs = self.thumbnails.map { $0.windowID }
                let newIDs = updated.map { $0.windowID }

                if Set(oldIDs) != Set(newIDs) {
                    // 데스크탑 전환 — 윈도우 목록 자체가 바뀜
                    if self.currentIndex >= 0 {
                        self.resetState()
                        Logger.log("[KeyTap] 윈도우 목록 변경 → 리셋")
                    }
                    self.thumbnails = updated
                } else if self.currentIndex >= 0 {
                    // 같은 창들인데 좌표가 바뀜 — Spaces 바 레이아웃 변경 등
                    let currentWindowID = self.thumbnails[self.currentIndex].windowID
                    if let newIndex = updated.firstIndex(where: { $0.windowID == currentWindowID }) {
                        self.thumbnails = updated
                        self.currentIndex = newIndex
                        self.overlay.updateFrame(updated[newIndex].frame)
                    }
                } else {
                    self.thumbnails = updated
                }
            }

            self.mcWasActive = isActive
        }
        timer.resume()
        mcWatcher = timer
    }

    private func resetState() {
        currentIndex = -1
        thumbnails = []
        overlay.hide()
    }

    func stop() {
        mcWatcher?.cancel()
        mcWatcher = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        Logger.log("[KeyTap] 중지됨")
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Logger.log("[KeyTap] tap disabled (\(type.rawValue)) → 재활성화")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let mcActive = MissionControlDetector.isActive()
        if keyCode == 48 || keyCode == 36 {
            Logger.debug("[KeyTap] keyDown code=\(keyCode) mcActive=\(mcActive)")
        }
        guard mcActive else { return Unmanaged.passUnretained(event) }
        let flags = event.flags

        // Tab = 48, Enter = 36, ← = 123, → = 124, ↓ = 125, ↑ = 126
        switch keyCode {
        case 48: // Tab
            let isShift = flags.contains(.maskShift)
            Logger.log("[KeyTap] \(isShift ? "Shift+Tab" : "Tab") 가로챔")
            handleNavigation(direction: isShift ? .shiftTab : .tab)
            return nil

        case 123, 124, 125, 126: // 화살표 (Control+화살표는 Spaces/Exposé이므로 통과)
            guard !flags.contains(.maskControl) else {
                return Unmanaged.passUnretained(event)
            }
            let dir: NavigationDirection
            switch keyCode {
            case 123: dir = .left
            case 124: dir = .right
            case 125: dir = .down
            default:  dir = .up
            }
            Logger.log("[KeyTap] 화살표 \(dir) 가로챔")
            handleNavigation(direction: dir)
            return nil

        case 36: // Enter
            Logger.log("[KeyTap] Enter 가로챔")
            overlay.hide()
            CursorWarper.clickAtCurrentPosition()
            return nil

        case 51: // Command+Delete — 포커스된 앱 종료
            guard flags.contains(.maskCommand),
                  currentIndex >= 0 && currentIndex < thumbnails.count else {
                return Unmanaged.passUnretained(event)
            }
            let target = thumbnails[currentIndex]
            Logger.log("[KeyTap] Delete → \(target.ownerName) 종료")
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == target.ownerName }) {
                app.terminate()
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleNavigation(direction: NavigationDirection) {
        let newThumbnails = ThumbnailLocator.fetchThumbnails()
        if Set(thumbnails.map(\.windowID)) != Set(newThumbnails.map(\.windowID)) {
            currentIndex = -1
        }
        thumbnails = newThumbnails
        guard !thumbnails.isEmpty else {
            Logger.log("[KeyTap] thumbnail 없음 — 네비게이션 무시")
            return
        }

        currentIndex = ThumbnailNavigator.navigate(from: currentIndex, thumbnails: thumbnails, direction: direction)

        let target = thumbnails[currentIndex]
        Logger.log("[KeyTap] → index=\(currentIndex) \(target.ownerName) center=(\(Int(target.center.x)), \(Int(target.center.y)))")
        CursorWarper.warp(to: target.center)
        overlay.show(frame: target.frame)
    }
}
