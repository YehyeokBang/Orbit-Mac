import Cocoa

// Dock layer는 Mission Control 외에도 나타나므로 macOS 27에서는 WindowManager의 전체 화면 창 존재도 확인.
enum MissionControlDetector {
    // 실기기 관측(27.2): MC 진입 시 Dock layer 20보다 먼저 생기고, 종료 시 Dock layer 20보다 먼저 사라짐.
    // Apple이 보장하는 값이 아니므로 바뀌면 입력 통과로 동작하며 위 진단 로그가 남음.
    private static let macOS27MissionControlLayer = 19
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
        let candidate = list.contains { isWindow($0, owner: "Dock", layer: overlayLayer) }
        guard candidate else {
            wasRejected = false
            return false
        }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else { return true }

        let active = list.contains { isWindow($0, owner: "WindowManager", layer: macOS27MissionControlLayer) }
        if !active && !wasRejected {
            Logger.log("[MissionControlDetector] Dock layer 20 감지, Mission Control UI 없음 → 입력 통과")
        }
        wasRejected = !active
        return active
    }

    private static func isWindow(_ window: [String: Any], owner: String, layer: Int) -> Bool {
        window[kCGWindowOwnerName as String] as? String == owner && window[kCGWindowLayer as String] as? Int == layer
    }
}
