import SwiftUI
import AppKit

// 使用属性包装器，兼容没有 SwiftUIMacros 插件的 Command Line Tools。
private typealias ViewState<Value> = State<Value>

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @ViewState private var volumes: [VolumeInfo] = []
    @ViewState private var accessibilityGranted = Accessibility.check()

    var body: some View {
        Form {
            Section("总开关") {
                Toggle("启用自动展开", isOn: $settings.isEnabled)
                Text("关闭后不再自动展开任何窗口，菜单栏里也可以随时开关。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("适用硬盘") {
                ForEach(volumes) { volume in
                    Toggle(isOn: binding(for: volume)) {
                        HStack {
                            Text(volume.name)
                            Text(volume.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if volume.isRemovable {
                                Text("可移除")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                Button("重新扫描硬盘") { refreshVolumes() }
                Text("电脑里新插入的硬盘默认自动启用；不想用的在这里关掉。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("时间设置") {
                HStack {
                    Text("打开窗口后延迟")
                    Spacer()
                    TextField("", value: $settings.delayAfterOpen, format: .number)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                    Text("秒")
                }
                HStack {
                    Text("每展开一组间隔")
                    Spacer()
                    TextField("", value: $settings.intervalBetweenGroups, format: .number)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                    Text("秒")
                }
                HStack {
                    Text("没展开完时，多久后再补扫")
                    Spacer()
                    TextField("", value: $settings.rescanDelay, format: .number)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                    Text("秒")
                }
                HStack {
                    Text("一轮最多点几次")
                    Spacer()
                    TextField("", value: $settings.maxPasses, format: .number)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                    Text("次")
                }
            }

            Section("其他") {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                Toggle("显示菜单栏图标", isOn: $settings.showMenuBarIcon)
                Toggle("记录运行日志", isOn: $settings.loggingEnabled)
                Button("打开日志文件") {
                    if !FileManager.default.fileExists(atPath: AppLog.fileURL.path) {
                        try? "".write(to: AppLog.fileURL, atomically: true, encoding: .utf8)
                    }
                    NSWorkspace.shared.open(AppLog.fileURL)
                }
            }

            Section("辅助功能权限") {
                HStack {
                    Text(accessibilityGranted ? "已获得，可以正常工作" : "还没获得，自动展开不会生效")
                    Spacer()
                    Button("打开系统设置") { Accessibility.openSystemSettings() }
                }
                Button("重新检查权限") { accessibilityGranted = Accessibility.check() }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .onAppear { refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)
            .receive(on: DispatchQueue.main)) { _ in refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)
            .receive(on: DispatchQueue.main)) { _ in refreshVolumes() }
    }

    private func refreshVolumes() {
        volumes = VolumeScanner.mountedVolumes()
    }

    private func binding(for volume: VolumeInfo) -> Binding<Bool> {
        Binding(
            get: { settings.isVolumeEnabled(volume) },
            set: { settings.setVolumeEnabled(volume, $0) }
        )
    }
}
