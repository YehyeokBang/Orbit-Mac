import Cocoa

// Mission Control 활성 여부 감지.
// MC가 열리면 Dock 프로세스가 overlay 창을 만든다.
// 관측값: macOS 15는 layer=18, macOS 27은 layer=20.
enum MissionControlDetector {
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
        return list.contains { window in
            let owner = window[kCGWindowOwnerName as String] as? String
            let layer = window[kCGWindowLayer as String] as? Int
            return owner == "Dock" && layer == overlayLayer
        }
    }
}
