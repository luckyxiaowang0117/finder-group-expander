#!/bin/bash
# 在 Mac 上把源码打包成 .app（给 Codex 或手动执行用）
# 用法：bash build-app.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="FinderGroupExpander"

echo "==> 1/3 编译 (swift build -c release) ..."
swift build -c release

echo "==> 2/3 组装 $APP_NAME.app ..."
rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_NAME.app/Contents/MacOS/$APP_NAME"
install -m 644 Info.plist "$APP_NAME.app/Contents/Info.plist"
install -m 644 AppIcon.icns "$APP_NAME.app/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_NAME.app/Contents/PkgInfo"

echo "==> 3/3 ad-hoc 签名（仅本机运行可用）..."
codesign --force --deep --sign - "$APP_NAME.app" || echo "签名失败，仍可尝试直接运行（见 README 的说明）"

echo "完成：$(pwd)/$APP_NAME.app"
echo "首次运行：把 .app 拖进“应用程序”，右键 → 打开一次；再去系统设置 → 隐私与安全性 → 辅助功能，给它开权限。"
