# Contributing

ありがとうございます。小さな修正から歓迎します。

## 開発環境

- macOS 13 以降
- Xcode Command Line Tools（`xcode-select --install`）— `swiftc` が必要
- Node.js 16 以降（CLI をいじる場合）

## macOS アプリ（PaperOverlay）

```bash
cd macos/PaperOverlay
./build-app.sh            # PaperOverlay.app を生成
open PaperOverlay.app     # 起動（メニューバーに 📄）
```

`main.swift` 1ファイル構成です。主要な構造:

- `Settings` — 強さ（grain / warmth / dim）と有効状態を UserDefaults に永続化
- `OverlayView` — 各ディスプレイに重ねる描画（ノイズ／暖色／減光）
- `AppController` — メニューバー・ポップオーバー・ウィンドウ管理・ホットキー・プロセス間コマンド
- `PanelViewController` — ミニアプリ風の設定パネル

### 注意点

- パネルの outlet は遅延初期化されるため、外部から状態反映するときは `isViewLoaded` を必ず確認する。
- 単一起動は `/tmp/…lock` の `flock` で保証している。
- プロセス間のオン/オフは `DistributedNotificationCenter`（`--toggle/--on/--off/--quit`）で行う。

## CLI（npm）

```bash
node bin/paper-overlay.js start   # ローカルで動作確認
```

## プルリクエスト

- 1 PR = 1 論点。コミットメッセージは Conventional Commits（`feat:` `fix:` など）。
- UI やオーバーレイの見た目を変える場合は、Before/After のスクリーンショットを添えてください。

## ライセンス

貢献は MIT ライセンスの下で受け入れられます。
