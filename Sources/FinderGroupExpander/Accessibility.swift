import AppKit
import ApplicationServices

/// 辅助功能权限检查与引导。
enum Accessibility {
    /// 当前进程是否已经拿到辅助功能权限。
    static func check() -> Bool {
        AXIsProcessTrusted()
    }

    /// 弹系统提示，让用户去开权限（只在还没权限时调用才有效）。
    static func prompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// 打开「系统设置 → 隐私与安全性 → 辅助功能」。
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
