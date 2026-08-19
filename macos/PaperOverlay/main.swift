// PaperOverlay — ディスプレイ全体を「紙のような質感」にする常駐オーバーレイ
//
// 透明・クリック透過・全スペース/全画面対応の窓を各ディスプレイに重ね、
// 紙ノイズ(grain) + 暖色(warmth, 青カット) + 減光(dim) を描画します。
// メニューバーのアイコンからスライダーで強さを調整できます。
//
// 注意: OSのオーバーレイ窓は下の画面に対して「乗算合成」ができないため、
// Web版より粒はやや薄めに見えます（通常合成のみ）。グレア低減には十分効きます。
//
// ビルド:  ./build.sh   実行: ./paper-overlay
// 出典:    github.com/ShotaNagafuchi/display-visual

import AppKit

// MARK: - 設定（強さ）

final class Settings {
    static let shared = Settings()
    var grain: CGFloat  = 0.10   // 紙ノイズの強さ  0.0 – 0.5
    var warmth: CGFloat = 0.06   // 暖色(青カット)  0.0 – 0.35
    var dim: CGFloat    = 0.0    // 減光            0.0 – 0.5
    var enabled: Bool   = true

    private let key = "PaperOverlaySettings"
    func load() {
        let d = UserDefaults.standard
        if d.object(forKey: key) != nil {
            grain  = CGFloat(d.double(forKey: key + ".grain"))
            warmth = CGFloat(d.double(forKey: key + ".warmth"))
            dim    = CGFloat(d.double(forKey: key + ".dim"))
            enabled = d.bool(forKey: key + ".enabled")
        }
    }
    func save() {
        let d = UserDefaults.standard
        d.set(true, forKey: key)
        d.set(Double(grain),  forKey: key + ".grain")
        d.set(Double(warmth), forKey: key + ".warmth")
        d.set(Double(dim),    forKey: key + ".dim")
        d.set(enabled,        forKey: key + ".enabled")
    }
}

// MARK: - ノイズタイル生成（一度だけ）

func makeNoiseTile(size: Int = 180) -> CGImage {
    let bytesPerPixel = 4
    let bytesPerRow = size * bytesPerPixel
    var data = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
    for i in 0..<(size * size) {
        // 中間グレー中心のランダム輝度（紙の繊維の濃淡）
        let g = UInt8(90 + Int.random(in: 0...100))
        let o = i * bytesPerPixel
        data[o + 0] = g   // R
        data[o + 1] = g   // G
        data[o + 2] = g   // B
        data[o + 3] = 255 // A（不透明度は描画時に setAlpha で制御）
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: &data, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                        space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}

let noiseTile = makeNoiseTile()

// MARK: - オーバーレイ描画ビュー

final class OverlayView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = Settings.shared
        let b = bounds

        // 1) 紙ノイズをタイル描画
        if s.grain > 0.001 {
            ctx.saveGState()
            ctx.setAlpha(s.grain)
            let tw = CGFloat(noiseTile.width), th = CGFloat(noiseTile.height)
            var y: CGFloat = 0
            while y < b.height {
                var x: CGFloat = 0
                while x < b.width {
                    ctx.draw(noiseTile, in: CGRect(x: x, y: y, width: tw, height: th))
                    x += tw
                }
                y += th
            }
            ctx.restoreGState()
        }

        // 2) 暖色（青カット）
        if s.warmth > 0.001 {
            ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.36, alpha: s.warmth).cgColor)
            ctx.fill(b)
        }

        // 3) 減光
        if s.dim > 0.001 {
            ctx.setFillColor(NSColor(calibratedWhite: 0.0, alpha: s.dim).cgColor)
            ctx.fill(b)
        }
    }
}

// MARK: - アプリ本体

final class AppController: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var statusItem: NSStatusItem!
    private var grainSlider: NSSlider!
    private var warmthSlider: NSSlider!
    private var dimSlider: NSSlider!

    func applicationDidFinishLaunching(_ note: Notification) {
        Settings.shared.load()
        buildStatusItem()
        rebuildWindows()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screensChanged() { rebuildWindows() }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard Settings.shared.enabled else { return }
        for screen in NSScreen.screens {
            let w = NSWindow(contentRect: screen.frame,
                             styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                    .fullScreenAuxiliary, .ignoresCycle]
            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            w.contentView = view
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
    }

    private func redraw() { windows.forEach { $0.contentView?.needsDisplay = true } }

    // MARK: メニューバー

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.title = "📄"
            btn.toolTip = "PaperOverlay — 画面を紙化"
        }
        let menu = NSMenu()

        menu.addItem(sliderItem(title: "紙ノイズ", value: Settings.shared.grain,
                                max: 0.5, action: #selector(grainChanged(_:)),
                                assign: { self.grainSlider = $0 }))
        menu.addItem(sliderItem(title: "暖かさ(青カット)", value: Settings.shared.warmth,
                                max: 0.35, action: #selector(warmthChanged(_:)),
                                assign: { self.warmthSlider = $0 }))
        menu.addItem(sliderItem(title: "減光", value: Settings.shared.dim,
                                max: 0.5, action: #selector(dimChanged(_:)),
                                assign: { self.dimSlider = $0 }))
        menu.addItem(.separator())

        addPreset(to: menu, title: "プリセット: やさしめ", g: 0.06, w: 0.03, d: 0.0)
        addPreset(to: menu, title: "プリセット: 紙",       g: 0.12, w: 0.08, d: 0.04)
        addPreset(to: menu, title: "プリセット: 最大",     g: 0.28, w: 0.18, d: 0.12)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: Settings.shared.enabled ? "オフにする" : "オンにする",
                                action: #selector(toggleEnabled(_:)), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let quit = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func sliderItem(title: String, value: CGFloat, max: Double,
                            action: Selector, assign: (NSSlider) -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 46))

        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 14, y: 24, width: 200, height: 16)
        label.font = .menuFont(ofSize: 12)
        container.addSubview(label)

        let slider = NSSlider(value: Double(value), minValue: 0, maxValue: max,
                              target: self, action: action)
        slider.frame = NSRect(x: 14, y: 4, width: 192, height: 20)
        container.addSubview(slider)
        assign(slider)

        item.view = container
        return item
    }

    private func addPreset(to menu: NSMenu, title: String,
                           g: CGFloat, w: CGFloat, d: CGFloat) {
        let item = NSMenuItem(title: title, action: #selector(applyPreset(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = [g, w, d]
        menu.addItem(item)
    }

    @objc private func grainChanged(_ s: NSSlider)  { Settings.shared.grain  = CGFloat(s.doubleValue); Settings.shared.save(); redraw() }
    @objc private func warmthChanged(_ s: NSSlider) { Settings.shared.warmth = CGFloat(s.doubleValue); Settings.shared.save(); redraw() }
    @objc private func dimChanged(_ s: NSSlider)    { Settings.shared.dim    = CGFloat(s.doubleValue); Settings.shared.save(); redraw() }

    @objc private func applyPreset(_ item: NSMenuItem) {
        guard let v = item.representedObject as? [CGFloat], v.count == 3 else { return }
        let s = Settings.shared
        s.grain = v[0]; s.warmth = v[1]; s.dim = v[2]; s.save()
        grainSlider.doubleValue = Double(v[0])
        warmthSlider.doubleValue = Double(v[1])
        dimSlider.doubleValue = Double(v[2])
        if !s.enabled { s.enabled = true; rebuildWindows() }
        redraw()
    }

    @objc private func toggleEnabled(_ item: NSMenuItem) {
        Settings.shared.enabled.toggle()
        Settings.shared.save()
        item.title = Settings.shared.enabled ? "オフにする" : "オンにする"
        rebuildWindows()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dockに出さない常駐アプリ
let controller = AppController()
app.delegate = controller
app.run()
