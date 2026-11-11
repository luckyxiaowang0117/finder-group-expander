import Foundation

/// 简易运行日志：写到 ~/Library/Logs/FinderGroupExpander.log，可在设置里开关。
enum AppLog {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/FinderGroupExpander.log")

    static var enabled: Bool {
        SettingsStore.shared.loggingEnabled
    }

    static func write(_ message: String) {
        guard enabled else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // 日志写失败不影响主功能，静默忽略
        }
    }
}
