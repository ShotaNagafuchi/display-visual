#!/bin/bash
# PaperOverlay.app（配布用アプリバンドル）をビルドする。
# 生成物: ./PaperOverlay.app
set -euo pipefail
cd "$(dirname "$0")"

APP="PaperOverlay.app"
VERSION="${1:-1.0.0}"
BUNDLE_ID="com.display-visual.paperoverlay"

echo "▶ ビルド中 (v$VERSION)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# ユニバーサルバイナリ（Apple Silicon + Intel）
swiftc -O -target arm64-apple-macos13.0  main.swift -o /tmp/po-arm64
swiftc -O -target x86_64-apple-macos13.0 main.swift -o /tmp/po-x86_64 2>/dev/null \
  && lipo -create /tmp/po-arm64 /tmp/po-x86_64 -output "$APP/Contents/MacOS/PaperOverlay" \
  || { echo "  (x86_64ツールチェーン無し → arm64のみでビルド)"; cp /tmp/po-arm64 "$APP/Contents/MacOS/PaperOverlay"; }
chmod +x "$APP/Contents/MacOS/PaperOverlay"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PaperOverlay</string>
  <key>CFBundleDisplayName</key><string>PaperOverlay</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>PaperOverlay</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License · github.com/ShotaNagafuchi/display-visual</string>
</dict>
</plist>
PLIST

# ad-hoc 署名（ログイン項目/Gatekeeper の挙動を安定させる。公証は別途）
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"

echo "✅ 完成: $(pwd)/$APP"
echo "   実行:  open $APP"
echo "   配置:  cp -R $APP /Applications/   （ログイン項目に登録するなら /Applications 推奨）"
