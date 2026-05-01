import Cocoa

enum Permissions {
    static func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility 권한 필요"
            alert.informativeText = "시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 Orbit을 허용해주세요.\n권한 부여 후 앱을 재시작하세요."
            alert.addButton(withTitle: "시스템 설정 열기")
            alert.addButton(withTitle: "나중에")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
