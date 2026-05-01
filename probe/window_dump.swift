// 실행: swiftc window_dump.swift -o window_dump && ./window_dump
// Mission Control 활성 상태에서 실행하면 /tmp/orbit_windows.txt에 덤프됨
// 목적: CGWindowListCopyWindowInfo가 thumbnail 좌표를 반환하는지 확인

import Cocoa

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    print("창 목록 가져오기 실패")
    exit(1)
}

var output = "=== Window Dump (Mission Control 활성 중에 실행했나요?) ===\n"
output += "총 창 수: \(windowList.count)\n\n"

for (i, window) in windowList.enumerated() {
    let name = window[kCGWindowName as String] as? String ?? "(no name)"
    let owner = window[kCGWindowOwnerName as String] as? String ?? "(unknown)"
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let x = bounds["X"] ?? 0
    let y = bounds["Y"] ?? 0
    let w = bounds["Width"] ?? 0
    let h = bounds["Height"] ?? 0

    // layer 0이 일반 앱 창, 그것만 출력
    if layer == 0 || layer == 1 {
        output += "[\(i)] \(owner) — \(name)\n"
        output += "    layer=\(layer) x=\(x) y=\(y) w=\(w) h=\(h)\n"
    }
}

let path = "/tmp/orbit_windows.txt"
try! output.write(toFile: path, atomically: true, encoding: .utf8)
print("덤프 완료: \(path)")
print(output)
