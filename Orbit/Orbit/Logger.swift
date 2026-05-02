import Foundation

enum Logger {
    // ORBIT_DEBUG=1 환경변수일 때만 debug 메시지 출력. 평상시엔 info만.
    private static let debugEnabled: Bool = ProcessInfo.processInfo.environment["ORBIT_DEBUG"] == "1"

    private static let logURL: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("Orbit.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func debug(_ message: String) {
        guard debugEnabled else { return }
        log(message)
    }

    static func log(_ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        print(line, terminator: "")
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: logURL)
        }
    }
}
