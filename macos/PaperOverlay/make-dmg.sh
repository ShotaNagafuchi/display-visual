#!/bin/bash
# ドラッグ&ドロップでインストールできる DMG を作る。
# 生成物: ./PaperOverlay.dmg （app と Applications ショートカット入り）
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
APP="PaperOverlay.app"
DMG="PaperOverlay.dmg"

[ -d "$APP" ] || ./build-app.sh "$VERSION"

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # ドラッグ先のショートカット

rm -f "$DMG"
hdiutil create -volname "PaperOverlay" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✅ 完成: $(pwd)/$DMG"
echo "   マウントすると app を Applications にドラッグして設置できます。"
