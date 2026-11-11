import Foundation
import Combine
import ServiceManagement

/// 设置的唯一存放处：UserDefaults 持久化，SwiftUI 界面直接绑定。
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let delayAfterOpen = "delayAfterOpen"
        static let rescanDelay = "rescanDelay"
        static let intervalBetweenGroups = "intervalBetweenGroups"
        static let maxPasses = "maxPasses"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let loggingEnabled = "loggingEnabled"
        static let volumeOverrides = "volumeOverrides"
        static let volumeOverridesByIdentity = "volumeOverridesByIdentity"
    }

    /// 总开关
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    /// 打开窗口后延迟多久开始展开（秒）
    @Published var delayAfterOpen: Double {
        didSet { defaults.set(delayAfterOpen, forKey: Keys.delayAfterOpen) }
    }

    /// 一轮没点完时，多久后再补扫（秒）
    @Published var rescanDelay: Double {
        didSet { defaults.set(rescanDelay, forKey: Keys.rescanDelay) }
    }

    /// 每展开一组间隔多久（秒）
    @Published var intervalBetweenGroups: Double {
        didSet { defaults.set(intervalBetweenGroups, forKey: Keys.intervalBetweenGroups) }
    }

    /// 一轮最多点几次
    @Published var maxPasses: Int {
        didSet { defaults.set(maxPasses, forKey: Keys.maxPasses) }
    }

    /// 开机自动启动
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    /// 显示菜单栏图标
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    /// 记录运行日志
    @Published var loggingEnabled: Bool {
        didSet { defaults.set(loggingEnabled, forKey: Keys.loggingEnabled) }
    }

    private let legacyVolumeOverrides: [String: Bool]

    /// 优先按卷 UUID 保存，没有 UUID 时使用挂载路径。
    @Published private(set) var volumeOverridesByIdentity: [String: Bool] {
        didSet { defaults.set(volumeOverridesByIdentity, forKey: Keys.volumeOverridesByIdentity) }
    }

    private init() {
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.delayAfterOpen = defaults.object(forKey: Keys.delayAfterOpen) as? Double ?? 0.2
        self.rescanDelay = defaults.object(forKey: Keys.rescanDelay) as? Double ?? 0.8
        self.intervalBetweenGroups = defaults.object(forKey: Keys.intervalBetweenGroups) as? Double ?? 0.2
        self.maxPasses = defaults.object(forKey: Keys.maxPasses) as? Int ?? 10
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.loggingEnabled = defaults.object(forKey: Keys.loggingEnabled) as? Bool ?? true

        self.legacyVolumeOverrides = defaults.dictionary(forKey: Keys.volumeOverrides) as? [String: Bool] ?? [:]
        self.volumeOverridesByIdentity = defaults.dictionary(forKey: Keys.volumeOverridesByIdentity) as? [String: Bool] ?? [:]
    }

    func isVolumeEnabled(_ volume: VolumeInfo) -> Bool {
        volumeOverridesByIdentity[volume.preferenceKey] ?? legacyVolumeOverrides[volume.name] ?? true
    }

    func setVolumeEnabled(_ volume: VolumeInfo, _ enabled: Bool) {
        volumeOverridesByIdentity[volume.preferenceKey] = enabled
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.write("开机自启设置失败：\(error.localizedDescription)")
        }
    }
}
