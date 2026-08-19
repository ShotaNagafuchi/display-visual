#!/bin/bash
# PaperOverlay をビルドする。生成物: ./paper-overlay
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O main.swift -o paper-overlay
echo "✅ ビルド完了: $(pwd)/paper-overlay"
echo "   実行: ./paper-overlay   （メニューバーに 📄 が出ます）"
