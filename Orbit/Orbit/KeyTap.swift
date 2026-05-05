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

    // 프레임 안정화 감지 — 연속 stableRequired회 폴링에서 좌표가 동일하면 애니메이션 완료로 판단.
    // 시간 기반(asyncAfter)이 아닌 실제 상태 기반이므로 렉/성능 변동에 무관하게 정확.
    private var lastFrameKey = ""
    private var stableCount = 0
    private let stableRequired = 2
    private var lastActivePID: pid_t = 0

    func start() {
        guard AXIsProcessTrusted() else {
            Logger.log("[KeyTap] Accessibility 권한 없음 — 시스템 설정 > 손쉬운 사용에서 Orbit 허용 후 재시작")
            Permissions.showAccessibilityAlert()
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

        // 데스크탑 전환 즉시 감지: 번호 잔상 즉시 제거 + 안정화 카운트 리셋.
        // 이 notification은 1회 전환에 최대 3번 발화 → hide만, 재표시는 mcWatcher가 담당.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.mcWasActive else { return }
            self.stableCount = 0
            NumberOverlay.shared.hide()
        }

        startMCWatcher()
        Logger.log("[KeyTap] 시작됨")
    }

    // MC 상태 + thumbnail 프레임 안정화를 주기적으로 감시.
    // 번호 표시 정책: 연속 stableRequired회 폴링에서 좌표가 동일하면 애니메이션 완료로 판단 → 즉시 표시.
    // 좌표가 바뀌는 동안(애니메이션 중, Spaces 바 hover 중)은 숨김 유지.
    private func startMCWatcher() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let isActive = MissionControlDetector.isActive()

            if !isActive, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
                self.lastActivePID = pid
            }

            if self.mcWasActive && !isActive {
                self.resetState()
                Logger.log("[KeyTap] MC 종료 감지 → 리셋")
            } else if isActive {
                let updated = ThumbnailLocator.fetchThumbnails()
                let oldIDs = Set(self.thumbnails.map { $0.windowID })
                let newIDs = Set(updated.map { $0.windowID })

                if oldIDs != newIDs {
                    // ID 세트 변경 (MC 첫 활성화 or 데스크탑 전환)
                    if self.currentIndex >= 0 {
                        self.currentIndex = -1
                        self.overlay.hide()
                    }
                    self.thumbnails = updated
                    NumberOverlay.shared.hide()
                    self.stableCount = 0
                    self.lastFrameKey = self.frameKey(updated)
                } else if !updated.isEmpty {
                    let newKey = self.frameKey(updated)
                    if newKey == self.lastFrameKey {
                        // 좌표 안정 중
                        if self.stableCount < self.stableRequired {
                            self.stableCount += 1
                            if self.stableCount == self.stableRequired {
                                // 안정화 완료 → 번호 표시 + 이전 창 자동 포커스
                                self.thumbnails = updated
                                let order = ThumbnailNavigator.readingOrder(updated)
                                NumberOverlay.shared.show(thumbnails: updated, order: order)
                                Logger.log("[KeyTap] 프레임 안정화 감지 → 번호 표시")
                                if self.currentIndex < 0 {
                                    self.autoFocusPreviousWindow()
                                }
                            }
                        } else {
                            // 이미 안정화 상태 — 번호·선택 오버레이 위치만 갱신
                            if self.currentIndex >= 0 {
                                let wid = self.thumbnails[self.currentIndex].windowID
                                if let idx = updated.firstIndex(where: { $0.windowID == wid }) {
                                    self.thumbnails = updated
                                    self.currentIndex = idx
                                    self.overlay.updateFrame(updated[idx].frame)
                                }
                            }
                            let order = ThumbnailNavigator.readingOrder(updated)
                            NumberOverlay.shared.update(thumbnails: updated, order: order)
                        }
                    } else {
                        // 좌표 변경 중 (애니메이션 진행 / Spaces 바 hover)
                        self.stableCount = 0
                        self.lastFrameKey = newKey
                        NumberOverlay.shared.hide()
                        // 선택 오버레이는 따라가도록 유지
                        if self.currentIndex >= 0 {
                            let wid = self.thumbnails[self.currentIndex].windowID
                            if let idx = updated.firstIndex(where: { $0.windowID == wid }) {
                                self.thumbnails = updated
                                self.currentIndex = idx
                                self.overlay.updateFrame(updated[idx].frame)
                            }
                        }
                    }
                }
            }

            self.mcWasActive = isActive
        }
        timer.resume()
        mcWatcher = timer
    }

    // thumbnail 좌표를 정수 단위로 키 생성. windowID 순 정렬로 배열 순서 무관하게 동일 키 보장.
    private func frameKey(_ thumbnails: [WindowThumbnail]) -> String {
        thumbnails.sorted { $0.windowID < $1.windowID }.map { t in
            "\(Int(t.frame.minX)),\(Int(t.frame.minY)),\(Int(t.frame.width)),\(Int(t.frame.height))"
        }.joined(separator: "|")
    }

    // MC 활성화 직전 포커스된 창을 찾아 자동으로 커서를 이동하고 선택 오버레이를 표시.
    // PID로 매칭하고, 없으면 아무것도 안 함 (첫 번째로 fallback하지 않음 — 의도치 않은 포커스 방지).
    private func autoFocusPreviousWindow() {
        guard lastActivePID != 0,
              let idx = thumbnails.firstIndex(where: { $0.ownerPID == lastActivePID }) else {
            Logger.log("[KeyTap] 이전 창 매칭 실패 (pid=\(lastActivePID)) → 자동 포커스 생략")
            return
        }
        currentIndex = idx
        CursorWarper.warp(to: thumbnails[idx].center)
        overlay.show(frame: thumbnails[idx].frame, appName: thumbnails[idx].ownerName)
        Logger.log("[KeyTap] 이전 창 자동 포커스 → \(thumbnails[idx].ownerName)")
    }

    private func resetState() {
        currentIndex = -1
        thumbnails = []
        stableCount = 0
        lastFrameKey = ""
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
            guard NumberKeySettings.shared.isEnabled else { return Unmanaged.passUnretained(event) }
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
