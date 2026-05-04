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

    // 번호 오버레이 안정화 추적: 직전 폴링에서 본 windowID 세트.
    // 연속 2번 동일한 세트 → 스프레드 완료로 판단 → 번호 표시.
    // nil = 이미 안정 상태(표시 중 or 숨김)
    private var idsSince: Set<CGWindowID>? = nil

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

        // 데스크탑 전환 즉시 감지: 폴링(0.2s) 대기 없이 번호 잔상 제거
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.mcWasActive else { return }
            NumberOverlay.shared.hide()
            // 안정화 재대기: 센티널(빈 세트)로 표시 → 이후 폴링에서 newIDs로 전환 후 재확인
            self.idsSince = Set<CGWindowID>()
        }

        startMCWatcher()
        Logger.log("[KeyTap] 시작됨")
    }

    // MC 상태 + thumbnail 변화를 주기적으로 감시.
    // 번호 표시 정책: windowID 세트가 연속 2번 동일해야 안정 → 표시.
    // (스프레드 애니메이션 중 좌표가 확정되지 않은 상태에서 번호가 매겨지는 문제 방지)
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
                    // 윈도우 세트 변경 — 애니메이션 중이거나 데스크탑 전환
                    if self.currentIndex >= 0 {
                        self.currentIndex = -1
                        self.overlay.hide()
                    }
                    self.thumbnails = updated
                    NumberOverlay.shared.hide()
                    self.idsSince = newIDs  // 안정화 대기 시작
                } else if let pending = self.idsSince {
                    // 이전 폴링과 동일한 세트 — 안정화 확인
                    if !updated.isEmpty && pending == newIDs {
                        // 연속 2번 동일 → 스프레드 완료, 번호 표시
                        let order = ThumbnailNavigator.readingOrder(updated)
                        NumberOverlay.shared.show(thumbnails: updated, order: order)
                        self.idsSince = nil
                    } else if !updated.isEmpty {
                        // 센티널이었거나 아직 전환 중 → 현재 세트를 pending으로 기록
                        self.idsSince = newIDs
                    }
                } else if self.currentIndex >= 0 && !updated.isEmpty {
                    // 안정 상태에서 좌표만 변경 (Spaces 바 레이아웃 등)
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

    private func resetState() {
        currentIndex = -1
        thumbnails = []
        idsSince = nil
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
            // 수식어 키 조합(Cmd+Shift+5 캡처 등)은 통과
            guard flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).isEmpty else {
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
