import AppKit
import ApplicationServices
import Combine

/// 核心引擎：定时巡查访达窗口，发现目标硬盘上的窗口里有「全部显示」按钮就点开。
/// 只用辅助功能的 AXPress 点按钮，全程后台，不动鼠标、不抢焦点。
///
/// 触发方式是每 0.5 秒巡查一次（不是逐窗口事件监听），目的是兼容各版本系统；
/// 巡查本身很轻量：只是读一下访达窗口的无障碍树。
final class Expander: NSObject {
    static let shared = Expander()

    private var detectionTimer: Timer?
    private var enabledSubscription: AnyCancellable?
    private var sessions: [AXUIElement: Timer] = [:]
    private var sessionEndedAt: [SessionKey: Date] = [:]

    private struct SessionKey: Hashable {
        let window: AXUIElement
        let location: String
    }

    private override init() { super.init() }

    func start() {
        guard detectionTimer == nil else { return }
        enabledSubscription = SettingsStore.shared.$isEnabled.sink { [weak self] enabled in
            if !enabled { self?.cancelSessions() }
        }
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.scanForTargetWindows()
        }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(scanNow), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(scanNow), name: NSWorkspace.didMountNotification, object: nil)
        scanForTargetWindows()
    }

    @objc private func scanNow() {
        DispatchQueue.main.async { [weak self] in
            self?.scanForTargetWindows()
        }
    }

    private func cancelSessions() {
        for timer in sessions.values {
            timer.invalidate()
        }
        sessions.removeAll()
        sessionEndedAt.removeAll()
    }

    // MARK: - 发现窗口

    private func finderPID() -> pid_t? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }?.processIdentifier
    }

    private func finderWindows() -> [AXUIElement] {
        guard let pid = finderPID() else { return [] }
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    /// 判断窗口是否在已启用的硬盘上，并返回当前目录标识。
    private func targetLocation(for window: AXUIElement, volumes: [VolumeInfo]) -> String? {
        let settings = SettingsStore.shared

        // 首选 AXDocument：访达窗口会暴露当前文件夹的 file:// URL，
        // 这样硬盘里的子文件夹窗口也能匹配到所属硬盘。
        if let document = stringAttribute(window, kAXDocumentAttribute),
           let url = URL(string: document), url.isFileURL,
           let volume = VolumeScanner.volumeContaining(path: url.path, in: volumes) {
            return settings.isVolumeEnabled(volume) ? url.path : nil
        }

        // 标题只能唯一匹配一个卷时，才用它识别根目录窗口。
        guard let title = stringAttribute(window, kAXTitleAttribute) else { return nil }
        let matches = volumes.filter { $0.name == title }
        guard matches.count == 1, let volume = matches.first,
              settings.isVolumeEnabled(volume) else { return nil }
        return volume.path
    }

    private func scanForTargetWindows() {
        let settings = SettingsStore.shared
        guard settings.isEnabled else { return }
        let now = Date()
        sessionEndedAt = sessionEndedAt.filter { now.timeIntervalSince($0.value) < settings.rescanDelay }
        let windows = finderWindows()
        guard !windows.isEmpty else { return }
        let volumes = VolumeScanner.mountedVolumes()
        for window in windows {
            guard sessions[window] == nil,
                  let location = targetLocation(for: window, volumes: volumes) else { continue }
            let key = SessionKey(window: window, location: location)
            if sessionEndedAt[key] != nil { continue }
            guard hasShowAllButtons(window) else { continue }
            startSession(key: key)
        }
    }

    // MARK: - 展开会话

    private func startSession(key: SessionKey) {
        let settings = SettingsStore.shared
        let window = key.window
        var remaining = settings.maxPasses
        // 防止设置里填了 0 或负数导致定时器乱跑
        let interval = max(settings.intervalBetweenGroups, 0.05)
        let delay = max(settings.delayAfterOpen, 0)
        AppLog.write("开始展开窗口：\(key.location)")
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            guard settings.isEnabled,
                  self.targetLocation(for: window, volumes: VolumeScanner.mountedVolumes()) == key.location else {
                t.invalidate()
                self.sessions.removeValue(forKey: window)
                return
            }
            var found: [AXUIElement] = []
            self.findShowAllButtons(in: window, depth: 0, out: &found)
            if found.isEmpty || remaining <= 0 {
                t.invalidate()
                self.sessions.removeValue(forKey: window)
                self.sessionEndedAt[key] = Date()
                AppLog.write("展开会话结束：\(key.location)，剩余按钮 \(found.count) 个")
                return
            }
            remaining -= 1
            let ok = self.press(found[0])
            AppLog.write("点开 1 个“全部显示”（\(key.location)），结果=\(ok)，还剩约 \(found.count - 1) 个")
        }
        // 第一轮在 delayAfterOpen 之后再动手，等窗口内容加载完
        timer.fireDate = Date(timeIntervalSinceNow: delay)
        sessions[window] = timer
    }

    // MARK: - 无障碍元素查找与点击

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func isShowAllButton(_ element: AXUIElement) -> Bool {
        guard let role = stringAttribute(element, kAXRoleAttribute),
              ["AXButton", "AXLink", "AXStaticText", "AXCell"].contains(role) else { return false }
        for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
            if let text = stringAttribute(element, attribute),
               text.contains("全部显示") || text.contains("Show All") {
                return true
            }
        }
        return false
    }

    private func findShowAllButtons(in element: AXUIElement, depth: Int, out: inout [AXUIElement]) {
        guard depth <= 15 else { return }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return }
        for child in children {
            if isShowAllButton(child) {
                out.append(child)
            } else {
                findShowAllButtons(in: child, depth: depth + 1, out: &out)
            }
        }
    }

    private func hasShowAllButtons(_ window: AXUIElement) -> Bool {
        var found: [AXUIElement] = []
        findShowAllButtons(in: window, depth: 0, out: &found)
        return !found.isEmpty
    }

    /// 只用 AXPress，后台点击，不动鼠标。
    private func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }
}
