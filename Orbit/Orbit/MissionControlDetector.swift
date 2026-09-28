import Cocoa

// Dock layer는 Mission Control 외에도 나타나므로 macOS 27에서는 접근성 UI 상태도 확인.
enum MissionControlDetector {
    private static var wasRejected = false
    private static let overlayLayer: Int? = {
        let version = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        switch version {
        case ..<27: return 18
        case 27: return 20
        default:
            Logger.log("[MissionControlDetector] macOS \(version): 확인되지 않은 Dock layer — Mission Control 감지 비활성")
            return nil
        }
    }()

    static func isActive() -> Bool {
        guard let overlayLayer else { return false }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let candidate = list.contains { window in
            let owner = window[kCGWindowOwnerName as String] as? String
            let layer = window[kCGWindowLayer as String] as? Int
            return owner == "Dock" && layer == overlayLayer
        }
        guard candidate else {
            wasRejected = false
            return false
        }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else { return true }

        let active = hasMissionControlUI()
        if !active && !wasRejected {
            Logger.log("[MissionControlDetector] Dock layer 20 감지, Mission Control UI 없음 → 입력 통과")
        }
        wasRejected = !active
        return active
    }

    // 실기기 관측: MC 진입 시 Dock의 직접 자식 AXGroup(identifier=mc)이 생성되고 종료 시 사라짐.
    // Apple이 보장하는 MC 상태 API는 아니므로 식별자 변경/조회 실패는 비활성으로 처리.
    private static func hasMissionControlUI() -> Bool {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return false
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.01)
        let deadline = ProcessInfo.processInfo.systemUptime + 0.03
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return false }

        let attributes = [kAXRoleAttribute, kAXIdentifierAttribute] as CFArray
        for child in children {
            // CGEventTap에서도 호출되므로 응답 없는 Dock이 키 입력을 오래 막지 않도록 제한.
            guard ProcessInfo.processInfo.systemUptime < deadline else { return false }
            AXUIElementSetMessagingTimeout(child, 0.01)
            var values: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(child, attributes, [], &values) == .success,
                  let fields = values as? [Any], fields.count == 2 else { return false }
            if fields[0] as? String == kAXGroupRole && fields[1] as? String == "mc" {
                return true
            }
        }
        return false
    }
}
