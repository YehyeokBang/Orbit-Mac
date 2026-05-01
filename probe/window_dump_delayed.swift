// swiftc window_dump_delayed.swift -o window_dump_delayed && ./window_dump_delayed
// 실행 후 5초 안에 Mission Control을 켜세요 (F3 또는 세 손가락 위 스와이프)

import Cocoa

print("5초 후 덤프합니다. 지금 Mission Control을 켜세요...")
for i in stride(from: 5, through: 1, by: -1) {
    print("\(i)...")
    sleep(1)
}
print("덤프!")

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    print("실패"); exit(1)
}

var output = "=== 총 창 수: \(windowList.count) ===\n\n"

for (i, window) in windowList.enumerated() {
    let owner = window[kCGWindowOwnerName as String] as? String ?? "?"
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let x = bounds["X"] ?? 0
    let y = bounds["Y"] ?? 0
    let w = bounds["Width"] ?? 0
    let h = bounds["Height"] ?? 0

    if layer == 0 {
        output += "[\(i)] \(owner)  x=\(x) y=\(y) w=\(w) h=\(h)\n"
    }
}

let path = "/tmp/orbit_mc_test.txt"
try! output.write(toFile: path, atomically: true, encoding: .utf8)
print("저장: \(path)")
print(output)
