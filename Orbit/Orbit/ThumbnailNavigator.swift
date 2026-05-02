import CoreGraphics

enum NavigationDirection {
    case tab, shiftTab, right, left, down, up
}

// Mission Control thumbnail 2D 네비게이션 알고리즘.
// Tab/ShiftTab: 행(row) 우선 읽기 순서로 순환.
// 화살표: 해당 방향 반평면에서 축-거리 + 교차축-거리×패널티로 최근접 선택.
enum ThumbnailNavigator {
    // 같은 행으로 묶는 Y 거리 기준 (px)
    private static let rowThreshold: CGFloat = 60
    // 방향 이동 시 교차축 거리 가중치
    private static let crossAxisPenalty: CGFloat = 2.0

    static func navigate(from currentIndex: Int, thumbnails: [WindowThumbnail], direction: NavigationDirection) -> Int {
        guard !thumbnails.isEmpty else { return currentIndex }
        switch direction {
        case .tab, .shiftTab:
            return navigateTab(from: currentIndex, thumbnails: thumbnails, reverse: direction == .shiftTab)
        default:
            return navigateDirectional(from: currentIndex, thumbnails: thumbnails, direction: direction)
        }
    }

    // 행-우선 읽기 순서(위→아래, 행 안에서 좌→우)로 정렬된 인덱스 배열에서 순환
    private static func navigateTab(from currentIndex: Int, thumbnails: [WindowThumbnail], reverse: Bool) -> Int {
        let ordered = readingOrder(thumbnails)
        if currentIndex < 0 {
            return reverse ? ordered[ordered.count - 1] : ordered[0]
        }
        guard let pos = ordered.firstIndex(of: currentIndex) else {
            return reverse ? ordered[ordered.count - 1] : ordered[0]
        }
        let next = reverse
            ? (pos - 1 + ordered.count) % ordered.count
            : (pos + 1) % ordered.count
        return ordered[next]
    }

    // thumbnails의 원본 인덱스를 행-우선 읽기 순서로 반환
    private static func readingOrder(_ thumbnails: [WindowThumbnail]) -> [Int] {
        let byY = (0..<thumbnails.count).sorted { thumbnails[$0].center.y < thumbnails[$1].center.y }

        var rows: [[Int]] = []
        var currentRow: [Int] = []
        var rowBaseY: CGFloat = -1

        for idx in byY {
            let cy = thumbnails[idx].center.y
            if rowBaseY < 0 {
                rowBaseY = cy
                currentRow = [idx]
            } else if abs(cy - rowBaseY) <= rowThreshold {
                currentRow.append(idx)
            } else {
                rows.append(currentRow)
                currentRow = [idx]
                rowBaseY = cy
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return rows.flatMap { row in
            row.sorted { thumbnails[$0].center.x < thumbnails[$1].center.x }
        }
    }

    // 방향 반평면 내 최근접 thumbnail 선택. 후보 없으면 현재 인덱스 유지.
    private static func navigateDirectional(from currentIndex: Int, thumbnails: [WindowThumbnail], direction: NavigationDirection) -> Int {
        // 포커스 없는 상태에서 화살표 → 첫 번째로 진입
        guard currentIndex >= 0 && currentIndex < thumbnails.count else { return 0 }
        let cur = thumbnails[currentIndex].center

        var bestIndex = -1
        var bestScore = CGFloat.infinity

        for (i, thumb) in thumbnails.enumerated() {
            guard i != currentIndex else { continue }
            let dx = thumb.center.x - cur.x
            let dy = thumb.center.y - cur.y

            let axis: CGFloat
            let cross: CGFloat
            switch direction {
            case .right:  guard dx > 0 else { continue }; axis = dx;  cross = abs(dy)
            case .left:   guard dx < 0 else { continue }; axis = -dx; cross = abs(dy)
            case .down:   guard dy > 0 else { continue }; axis = dy;  cross = abs(dx)
            case .up:     guard dy < 0 else { continue }; axis = -dy; cross = abs(dx)
            case .tab, .shiftTab: continue
            }

            let score = axis + cross * crossAxisPenalty
            if score < bestScore { bestScore = score; bestIndex = i }
        }

        return bestIndex >= 0 ? bestIndex : currentIndex
    }
}
