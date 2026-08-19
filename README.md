# display-visual — 画面を「紙のような質感」にして目の疲れを減らす

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-black)
![license](https://img.shields.io/badge/license-MIT-green)
![lang](https://img.shields.io/badge/Swift-6-orange)

物理フィルムを貼らず、**ソフトウェアだけ**で普通のディスプレイを「驚くほど目が疲れない紙のような質感」に近づけます。

長時間の発光画面が疲れる主因は3つ — ①**ピントの目印がない**（毛様体筋が緊張し続ける）②**純白 `#fff`×純黒 `#000` のハレーション**（文字の輪郭が発光して滲む）③**色情報の処理コスト**（赤い通知・広告・グラデーションが脳を消耗）。これを微細ノイズ・生成り色・低コントラスト・青カット／モノクロで打ち消します。

提供物は2系統:

1. 🖥 **PaperOverlay（macOSアプリ）** — 全アプリの上に紙ノイズ＋暖色＋減光を重ねる常駐アプリ。メニューバーと `⌘⌥P` で操作。
2. 🌐 **Web版（CSS / Stylus）** — ブラウザ内のサイトを紙化。

---

## 🖥 PaperOverlay（macOS）— ディスプレイ全体を紙化

VS Code・エディタ・PDF など**画面全体**に効きます。透明・クリック透過・全スペース/フルスクリーン対応。**画面収録などの権限は不要**です。

### インストール

**A. npm（開発者向け・いちばん手軽）**

```bash
npm install -g paperlike-overlay
paper-overlay start          # 初回はソースからビルドして ~/Applications に配置し起動
```

> 初回ビルドに Xcode Command Line Tools（`xcode-select --install`）が必要です。

**B. DMG をダウンロード（一般ユーザー向け）**

配布ページ: **https://shotanagafuchi.github.io/display-visual/**
または [Releases](https://github.com/ShotaNagafuchi/display-visual/releases) から `PaperOverlay.dmg` をDL。

1. `PaperOverlay.dmg` を開く
2. `PaperOverlay.app` を **Applications** にドラッグ
3. 初回だけ **右クリック →「開く」** で許可（未署名アプリのため）

> 起動時に「Applicationsに移動しますか？」と聞かれた場合は「移動して起動」でもOKです。

**C. ソースからビルド**

```bash
cd macos/PaperOverlay
./build-app.sh && open PaperOverlay.app
```

### 使い方

- メニューバーの **📄** をクリック → ミニアプリ風パネル（大きな ON/OFF スイッチ、紙ノイズ／暖かさ／減光のスライダー、プリセット、**ログイン時に起動**、終了）。
- **`⌘⌥P`（Command+Option+P）** でどのアプリからでも即オン/オフ。オフ時は 📄 が淡色に。
- 設定は保存され次回復元。**「ログイン時に起動」にチェック**すればセッションを閉じても再ログイン時に自動で立ち上がります。

### CLI

```bash
paper-overlay start | stop | toggle | on | off | status | build | install
```

### 仕組みと制約（正直な注記）

- OSのオーバーレイ窓は下の画面に対して**乗算合成ができず通常合成のみ**。そのため全画面版の粒は Web版（乗算）よりやや薄めに見えます。強い紙質感が欲しいページでは Web版の UserCSS を併用してください。
- **コントロールセンターへの常駐は不可**（Appleが公開APIを提供していないため）。メニューバーが定位置です。
- **配布に Apple Developer 登録（年$99）は不要**です。未署名DMGで配布でき、多くのOSSアプリも同様です。登録が要るのは「初回のGatekeeper警告を消す（Developer ID署名＋公証）」場合だけ。未公証でも **右クリック→開く** で普通に使えます。

---

## 🌐 Web版 — サイトを紙化する

### まず体感する（拡張不要）

```bash
open demo/index.html
```

右上のトグルで通常⇄紙モード、スライダーで粒の大きさ・ノイズ強さ・暖かさ・減光を調整できます。ノイズは**乗算合成**なので強弱の差がはっきり出ます。

### すべてのWebサイトを紙化する（Stylus）

1. **[Stylus](https://add0n.com/stylus.html)** をインストール
2. `userstyles/paper-like.user.css` を全文コピー → Stylus で新規スタイルに貼付 → 保存
3. Stylus のアイコンから **背景色 / 文字色 / ノイズ強さ / 暖かさ / 減光 / 行間 / 字間** を調整

### 自作サイト・ブログ

`snippets/paper.css` を読み込むだけ。紙ノイズは `mix-blend-mode: multiply` で重ねます。単体の紙ノイズは `snippets/noise.svg`。

### コードを書かない別案

- **Dark Reader**: モードを *ダーク* ではなく **Sepia**、コントラスト -10〜-20%。
- **Midnight Lizard**: 背景をテクスチャ、文字を任意インク色に一括変換。

---

## OS 全体の設定（標準機能・コード不要）

| 目的 | macOS |
|---|---|
| 暖かさ（青カット） | `システム設定 → ディスプレイ → Night Shift` |
| 減光（バックライト以上） | `アクセシビリティ → ディスプレイ → ホワイトポイントを下げる` |
| モノクロ | `アクセシビリティ → ディスプレイ → カラーフィルタ → グレイスケール` |

Windows: `設定 → アクセシビリティ → カラーフィルター → グレースケール`（ショートカット `Win+Ctrl+C`）。

---

## リポジトリ構成

```
display-visual/
├── macos/PaperOverlay/     # 常駐オーバーレイアプリ（Swift 1ファイル + ビルドスクリプト）
├── bin/paper-overlay.js    # npm CLI
├── demo/index.html         # Web版デモ（Before/After）
├── docs/index.html         # GitHub Pages 配布ページ
├── userstyles/             # Stylus 用 UserCSS
├── snippets/               # 自作サイト用 CSS / noise.svg
└── .github/workflows/      # タグ push で .dmg / .zip をリリースに添付
```

---

## 設計の根拠（採用値）

| 項目 | 値 | 理由 |
|---|---|---|
| 背景色 | `#f5f2eb`（生成り）/ `#f4eccf`（セピア） | 純白のバックライト直撃を避ける |
| 文字色 | `#2b2b2b`〜`#333`（炭黒） | 純黒の輪郭発光（ハレーション）を防ぐ |
| ノイズ | fractalNoise を **multiply** で重ねる（0.10〜0.34） | 脳が「紙」と誤認しピント調節が緩む。乗算なので薄くても粒が読める |
| 暖かさ | 暖色を乗算（青カット） | 夕方以降の刺激を下げる（f.lux 相当） |
| 行間/字間 | `1.8` / `0.05em` | 視線移動の認知負荷を下げる |

> **なぜ通常合成だと差がわからないのか:** 薄いグレーのノイズを明るい背景に通常合成しても画素がほぼ動きません。乗算で重ねると背景の明度に応じて粒が沈むため、同じ強さでも「紙の目」としてはっきり読めます。

---

## Contributing

[CONTRIBUTING.md](./CONTRIBUTING.md) を参照。

## License

[MIT](./LICENSE)
