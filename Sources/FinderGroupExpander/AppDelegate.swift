import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var toggleItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        SettingsStore.shared.$showMenuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in self?.updateStatusItemVisibility(show) }
            .store(in: &cancellables)

        Expander.shared.start()
        SettingsStore.shared.applyLaunchAtLogin()

        if !Accessibility.check() {
            Accessibility.prompt()
        }

        // 第一次启动时打开设置窗口，方便主人勾选硬盘和确认权限
        if !UserDefaults.standard.bool(forKey: "didLaunchBefore") {
            UserDefaults.standard.set(true, forKey: "didLaunchBefore")
            openSettings()
        }
    }

    // MARK: - 菜单栏

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "chevron.down.2", accessibilityDescription: "Finder 分组自动展开")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Finder 分组自动展开"

        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(title: "启用自动展开", action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        toggleItem = toggle

        let settings = NSMenuItem(title: "打开设置…", action: #selector(openSettingsAction(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        updateStatusItemVisibility(SettingsStore.shared.showMenuBarIcon)
    }

    private func updateStatusItemVisibility(_ show: Bool) {
        statusItem?.isVisible = show
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem?.state = SettingsStore.shared.isEnabled ? .on : .off
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        SettingsStore.shared.isEnabled.toggle()
        sender.state = SettingsStore.shared.isEnabled ? .on : .off
    }

    @objc private func openSettingsAction(_ sender: Any?) {
        openSettings()
    }

    // MARK: - 设置窗口

    func openSettings() {
        if let settingsWindow = settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Finder 分组自动展开"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 580))
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
