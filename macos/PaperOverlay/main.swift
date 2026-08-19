// PaperOverlay — ディスプレイ全体を「紙のような質感」にする常駐オーバーレイ
//
// 透明・クリック透過・全スペース/全画面対応の窓を各ディスプレイに重ね、
// 紙ノイズ(grain) + 暖色(warmth, 青カット) + 減光(dim) を描画します。
// メニューバーの 📄 をクリックするとミニアプリ風のパネルが開き、
// 大きな ON/OFF スイッチとスライダー・プリセットで調整できます。
// さらに ⌘⌥P のグローバルショートカットでどこからでもオン/オフできます。
//
// 注意: OSのオーバーレイ窓は下の画面に対して「乗算合成」ができないため、
// Web版より粒はやや薄めに見えます（通常合成のみ）。グレア低減には十分効きます。
//
// ビルド:  ./build.sh   実行: ./paper-overlay
// 出典:    github.com/ShotaNagafuchi/display-visual

import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    static let paperToggle = Notification.Name("com.display-visual.paperToggle")
}

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
        let g = UInt8(90 + Int.random(in: 0...100)) // 中間グレー中心のランダム輝度
        let o = i * bytesPerPixel
        data[o + 0] = g; data[o + 1] = g; data[o + 2] = g; data[o + 3] = 255
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: &data, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
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
        if s.grain > 0.001 {
            ctx.saveGState(); ctx.setAlpha(s.grain)
            let tw = CGFloat(noiseTile.width), th = CGFloat(noiseTile.height)
            var y: CGFloat = 0
            while y < b.height {
                var x: CGFloat = 0
                while x < b.width {
                    ctx.draw(noiseTile, in: CGRect(x: x, y: y, width: tw, height: th)); x += tw
                }
                y += th
            }
            ctx.restoreGState()
        }
        if s.warmth > 0.001 {
            ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.36, alpha: s.warmth).cgColor)
            ctx.fill(b)
        }
        if s.dim > 0.001 {
            ctx.setFillColor(NSColor(calibratedWhite: 0.0, alpha: s.dim).cgColor)
            ctx.fill(b)
        }
    }
}

// MARK: - グローバルショートカット（⌘⌥P）— Carbon、権限不要

private var hotKeyRef: EventHotKeyRef?

func installGlobalHotKey() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                             eventKind: OSType(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
        NotificationCenter.default.post(name: .paperToggle, object: nil)
        return noErr
    }, 1, &spec, nil, nil)

    let id = EventHotKeyID(signature: OSType(0x50415045), id: 1) // 'PAPE'
    RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | optionKey),
                        id, GetApplicationEventTarget(), 0, &hotKeyRef)
}

// MARK: - ミニアプリ風パネル

final class PanelViewController: NSViewController {
    weak var controller: AppController?
    private var powerSwitch: NSSwitch!
    private var grainSlider: NSSlider!, warmthSlider: NSSlider!, dimSlider: NSSlider!
    private var grainVal: NSTextField!, warmthVal: NSTextField!, dimVal: NSTextField!

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 322))

        // ヘッダー: タイトル + 大きな ON/OFF スイッチ
        let title = NSTextField(labelWithString: "PaperOverlay")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.frame = NSRect(x: 18, y: 286, width: 160, height: 22)
        root.addSubview(title)

        powerSwitch = NSSwitch(frame: NSRect(x: 224, y: 284, width: 40, height: 24))
        powerSwitch.state = Settings.shared.enabled ? .on : .off
        powerSwitch.target = self
        powerSwitch.action = #selector(switchChanged(_:))
        root.addSubview(powerSwitch)

        let hint = NSTextField(labelWithString: "⌘⌥P でどこからでもオン/オフ")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 18, y: 262, width: 246, height: 16)
        root.addSubview(hint)

        // スライダー3本
        grainVal  = addRow(to: root, y: 220, title: "紙ノイズ",         value: Settings.shared.grain,  max: 0.5,  action: #selector(grainChanged(_:)),  assign: { self.grainSlider = $0 })
        warmthVal = addRow(to: root, y: 168, title: "暖かさ(青カット)", value: Settings.shared.warmth, max: 0.35, action: #selector(warmthChanged(_:)), assign: { self.warmthSlider = $0 })
        dimVal    = addRow(to: root, y: 116, title: "減光",            value: Settings.shared.dim,    max: 0.5,  action: #selector(dimChanged(_:)),    assign: { self.dimSlider = $0 })

        // プリセット
        let presets: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("やさしめ", 0.06, 0.03, 0.0),
            ("紙",       0.12, 0.08, 0.04),
            ("最大",     0.28, 0.18, 0.12),
        ]
        for (i, p) in presets.enumerated() {
            let btn = NSButton(title: p.0, target: self, action: #selector(presetTapped(_:)))
            btn.bezelStyle = .rounded
            btn.frame = NSRect(x: 18 + CGFloat(i) * 84, y: 66, width: 78, height: 26)
            btn.tag = i
            btn.identifier = NSUserInterfaceItemIdentifier("\(p.1),\(p.2),\(p.3)")
            root.addSubview(btn)
        }

        // 区切り + 終了
        let sep = NSBox(frame: NSRect(x: 12, y: 52, width: 256, height: 1))
        sep.boxType = .separator
        root.addSubview(sep)

        let quit = NSButton(title: "終了", target: self, action: #selector(quitTapped))
        quit.bezelStyle = .rounded
        quit.frame = NSRect(x: 18, y: 16, width: 78, height: 26)
        root.addSubview(quit)

        self.view = root
    }

    private func addRow(to root: NSView, y: CGFloat, title: String, value: CGFloat,
                        max: Double, action: Selector, assign: (NSSlider) -> Void) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.frame = NSRect(x: 18, y: y + 22, width: 180, height: 16)
        root.addSubview(label)

        let valLabel = NSTextField(labelWithString: String(format: "%.2f", value))
        valLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valLabel.textColor = .secondaryLabelColor
        valLabel.alignment = .right
        valLabel.frame = NSRect(x: 204, y: y + 22, width: 60, height: 16)
        root.addSubview(valLabel)

        let slider = NSSlider(value: Double(value), minValue: 0, maxValue: max, target: self, action: action)
        slider.frame = NSRect(x: 18, y: y, width: 246, height: 20)
        root.addSubview(slider)
        assign(slider)
        return valLabel
    }

    // 外部（ショートカット等）から状態変化を反映
    func syncFromSettings() {
        powerSwitch.state = Settings.shared.enabled ? .on : .off
        grainSlider.doubleValue  = Double(Settings.shared.grain)
        warmthSlider.doubleValue = Double(Settings.shared.warmth)
        dimSlider.doubleValue    = Double(Settings.shared.dim)
        updateValueLabels()
    }
    private func updateValueLabels() {
        grainVal.stringValue  = String(format: "%.2f", Settings.shared.grain)
        warmthVal.stringValue = String(format: "%.2f", Settings.shared.warmth)
        dimVal.stringValue    = String(format: "%.2f", Settings.shared.dim)
    }

    @objc private func switchChanged(_ s: NSSwitch) { controller?.setEnabled(s.state == .on) }
    @objc private func grainChanged(_ s: NSSlider)  { Settings.shared.grain  = CGFloat(s.doubleValue); Settings.shared.save(); updateValueLabels(); controller?.redraw() }
    @objc private func warmthChanged(_ s: NSSlider) { Settings.shared.warmth = CGFloat(s.doubleValue); Settings.shared.save(); updateValueLabels(); controller?.redraw() }
    @objc private func dimChanged(_ s: NSSlider)    { Settings.shared.dim    = CGFloat(s.doubleValue); Settings.shared.save(); updateValueLabels(); controller?.redraw() }

    @objc private func presetTapped(_ b: NSButton) {
        guard let parts = b.identifier?.rawValue.split(separator: ",").map({ CGFloat(Double($0) ?? 0) }), parts.count == 3 else { return }
        let s = Settings.shared
        s.grain = parts[0]; s.warmth = parts[1]; s.dim = parts[2]
        if !s.enabled { controller?.setEnabled(true) }
        s.save()
        grainSlider.doubleValue = Double(parts[0])
        warmthSlider.doubleValue = Double(parts[1])
        dimSlider.doubleValue = Double(parts[2])
        updateValueLabels()
        controller?.redraw()
    }

    @objc private func quitTapped() { NSApp.terminate(nil) }
}

// MARK: - アプリ本体

final class AppController: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var panel: PanelViewController!

    func applicationDidFinishLaunching(_ note: Notification) {
        Settings.shared.load()
        buildStatusItem()
        buildPopover()
        rebuildWindows()
        installGlobalHotKey()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hotKeyToggle),
            name: .paperToggle, object: nil)
    }

    // MARK: 状態

    func setEnabled(_ on: Bool) {
        Settings.shared.enabled = on
        Settings.shared.save()
        rebuildWindows()
        updateIcon()
    }
    @objc private func hotKeyToggle() {
        setEnabled(!Settings.shared.enabled)
        panel?.syncFromSettings()
    }
    @objc private func screensChanged() { rebuildWindows() }
    func redraw() { windows.forEach { $0.contentView?.needsDisplay = true } }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard Settings.shared.enabled else { return }
        for screen in NSScreen.screens {
            let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            w.contentView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
    }

    // MARK: メニューバー + ポップオーバー

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📄"
        statusItem.button?.toolTip = "PaperOverlay — 画面を紙化（⌘⌥P でオン/オフ）"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        updateIcon()
    }

    private func buildPopover() {
        panel = PanelViewController()
        panel.controller = self
        popover.contentViewController = panel
        popover.behavior = .transient
    }

    private func updateIcon() {
        // オフ時はアイコンを淡色にして状態が分かるように
        statusItem.button?.appearsDisabled = !Settings.shared.enabled
    }

    @objc private func togglePopover() {
        guard let btn = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            panel.syncFromSettings()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dockに出さない常駐アプリ
let controller = AppController()
app.delegate = controller
app.run()
