import Cocoa

struct WindowThumbnail {
    let windowID: CGWindowID
    let ownerName: String
    let frame: CGRect  // Mission Control 활성 중 화면상의 thumbnail 좌표
    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
}

// Mission Control 활성 중 CGWindowListCopyWindowInfo로 thumbnail 좌표 획득.
// 검증 결과(2026-05-02): MC 활성 시 layer=0 창들의 frame이 thumbnail 위치/크기로 바뀜.
enum ThumbnailLocator {
    static func fetchThumbnails() -> [WindowThumbnail] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            Logger.log("[ThumbnailLocator] CGWindowListCopyWindowInfo 실패")
            return []
        }

        var thumbnails: [WindowThumbnail] = []
        for window in list {
            guard
                let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                let owner = window[kCGWindowOwnerName as String] as? String,
                let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            // Dock, WindowServer, Orbit 자체 창 제외
            if ["Dock", "Window Server", "Orbit"].contains(owner) { continue }

            let frame = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            guard frame.width > 50 && frame.height > 50 else { continue }

            thumbnails.append(WindowThumbnail(windowID: windowID, ownerName: owner, frame: frame))
        }

        // 왼쪽→오른쪽 우선, 같은 열이면 위→아래
        let sorted = thumbnails.sorted {
            if abs($0.frame.minX - $1.frame.minX) > 50 { return $0.frame.minX < $1.frame.minX }
            return $0.frame.minY < $1.frame.minY
        }

        Logger.log("[ThumbnailLocator] \(sorted.count)개 thumbnail: \(sorted.map { "\($0.ownerName)(\(Int($0.frame.minX)),\(Int($0.frame.minY)))" })")
        return sorted
    }
}
