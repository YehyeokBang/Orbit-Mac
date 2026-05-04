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

    // 번호 오버레이 지연 표시용 토큰.
    // thumbnail 세트가 바뀔 때마다 토큰을 증가시켜 이전 예약을 무효화.
    // 마지막 변화 이후 0.65s 뒤에 딱 한 번 표시.
    private var showToken = 0

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

        // 데스크탑 전환 즉시 감지: 번호 잔상 즉시 제거.
        // 이 notification은 1회 전환에 최대 3번 발화 → hide()만 호출, 재예약 없음.
        // 재표시는 mcWatcher가 thumbnail 변화를 감지했을 때 scheduleNumberOverlayShow()로 처리.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.mcWasActive else { return }
            NumberOverlay.shared.hide()
        }

        startMCWatcher()
        Logger.log("[KeyTap] 시작됨")
    }

    // MC 상태 + thumbnail 변화를 주기적으로 감시.
    // 번호 표시 정책: thumbnail windowID 세트가 바뀔 때마다 0.65s 지연 표시 예약.
    // 애니메이션 중 여러 번 바뀌어도 마지막 변화 후 한 번만 표시.
    private func startMCWatcher() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let isActive = MissionControlDetector.isActive()

            if self.mcWasActive && !isActive {
                self.resetState()
                Logger.log("[KeyTap] MC 종료 감지 → 리셋")
            } else if isActive {
                let updated = ThumbnailLocator.fetchThumbnails()
                let oldIDs = Set(self.thumbnails.map { $0.windowID })
                let newIDs = Set(updated.map { $0.windowID })

                if oldIDs != newIDs {
                    // MC 최초 활성 or 데스크탑 전환 — thumbnail 세트 변경
                    if self.currentIndex >= 0 {
                        self.currentIndex = -1
                        self.overlay.hide()
                    }
                    self.thumbnails = updated
                    NumberOverlay.shared.hide()
                    self.scheduleNumberOverlayShow()
                } else if self.currentIndex >= 0 && !updated.isEmpty {
                    // 같은 창들인데 좌표만 변경 (Spaces 바 레이아웃 등)
                    let currentWindowID = self.thumbnails[self.currentIndex].windowID
                    if let newIndex = updated.firstIndex(where: { $0.windowID == currentWindowID }) {
                        self.thumbnails = updated
                        self.currentIndex = newIndex
                        self.overlay.updateFrame(updated[newIndex].frame)
                    }
                    let order = ThumbnailNavigator.readingOrder(updated)
                    NumberOverlay.shared.update(thumbnails: updated, order: order)
                } else if !updated.isEmpty {
                    self.thumbnails = updated
                }
            }

            self.mcWasActive = isActive
        }
        timer.resume()
        mcWatcher = timer
    }

    // 0.65s 후 번호 오버레이 표시 예약. 토큰으로 이전 예약 자동 무효화.
    private func scheduleNumberOverlayShow() {
        showToken += 1
        let token = showToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.showToken == token else { return }
            guard MissionControlDetector.isActive() else { return }
            let fresh = ThumbnailLocator.fetchThumbnails()
            guard !fresh.isEmpty else { return }
            self.thumbnails = fresh
            let order = ThumbnailNavigator.readingOrder(fresh)
            NumberOverlay.shared.show(thumbnails: fresh, order: order)
        }
    }

    private func resetState() {
        showToken += 1  // 대기 중인 show 예약 취소
        currentIndex = -1
        thumbnails = []
        overlay.hide()
        NumberOverlay.shared.hide()
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
        // 숫자 1~9 = 18,19,20,21,23,22,26,28,25
        switch keyCode {
        case 18, 19, 20, 21, 22, 23, 25, 26, 28: // 1~9
            // 수식어 키 조합(Cmd+Shift+4 캡처 등)은 통과
            if flags.contains(.maskCommand) || flags.contains(.maskShift) ||
               flags.contains(.maskAlternate) || flags.contains(.maskControl) {
                Logger.debug("[KeyTap] 숫자 keyCode=\(keyCode) 수식어 감지 flags=\(flags.rawValue) → 통과")
                return Unmanaged.passUnretained(event)
            }
            let map: [Int: Int] = [18:1, 19:2, 20:3, 21:4, 22:6, 23:5, 25:9, 26:7, 28:8]
            guard let n = map[Int(keyCode)] else { return Unmanaged.passUnretained(event) }
            Logger.log("[KeyTap] 숫자 \(n) 가로챔")
            handleDirectJump(to: n)
            return nil

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

    private func handleDirectJump(to n: Int) {
        let newThumbnails = ThumbnailLocator.fetchThumbnails()
        if Set(thumbnails.map(\.windowID)) != Set(newThumbnails.map(\.windowID)) { currentIndex = -1 }
        thumbnails = newThumbnails
        guard !thumbnails.isEmpty else { return }

        let order = ThumbnailNavigator.readingOrder(thumbnails)
        let pos = n - 1
        guard pos < order.count else {
            Logger.log("[KeyTap] 숫자 \(n) → thumbnail \(order.count)개뿐 — 무시")
            return
        }
        currentIndex = order[pos]
        let target = thumbnails[currentIndex]
        Logger.log("[KeyTap] 숫자 \(n) → index=\(currentIndex) \(target.ownerName)")
        overlay.hide()
        NumberOverlay.shared.hide()
        CursorWarper.warp(to: target.center)
        CursorWarper.clickAtCurrentPosition()
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
        overlay.show(frame: target.frame, appName: target.ownerName)
    }
}
