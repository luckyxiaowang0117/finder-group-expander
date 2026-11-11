import AppKit

// 程序入口：标准 AppKit 启动方式（菜单栏常驻，没有 Dock 图标）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
