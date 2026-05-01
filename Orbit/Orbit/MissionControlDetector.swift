import Cocoa

// Mission Control 활성 여부 감지.
// MC가 열리면 Dock 프로세스가 layer=18 짜리 overlay 창을 만든다.
enum MissionControlDetector {
    static func isActive() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains { window in
            let owner = window[kCGWindowOwnerName as String] as? String
            let layer = window[kCGWindowLayer as String] as? Int
            return owner == "Dock" && layer == 18
        }
    }
}
