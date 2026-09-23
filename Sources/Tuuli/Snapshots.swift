import AppKit
import SwiftUI
import TuuliCore

/// `Tuuli --render-snapshots <dir>` renders the settings window with mock data, in light
/// and dark mode, for the README screenshots. Never touches the SMC, the helper or the
/// real settings.json.
@MainActor
enum Snapshots {
    static func render(to dir: URL) -> Int32 {
        setvbuf(stdout, nil, _IONBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var settings = Settings()
        settings.showAllSensors = true
        settings.adapterConfig.mode = .curve
        let store = SettingsStore(settings: settings)
        let monitor = mockMonitor()
        let helper = HelperClient()
        let engine = FanEngine()

        func both(_ name: String, pane: SettingsView.Pane) {
            for dark in [false, true] {
                let view = SettingsView(initialSelection: pane)
                    .environment(store)
                    .environment(monitor)
                    .environment(engine)
                    .environment(helper)
                snap(view, name: "\(name)-\(dark ? "dark" : "light")", title: pane.title, dark: dark, dir: dir)
            }
        }

        both("overview", pane: .overview)
        both("fans", pane: .fans)
        both("sensors", pane: .sensors)

        print("Snapshots written to \(dir.path)")
        return 0
    }

    // MARK: Sample data

    private static func mockMonitor() -> Monitor {
        let raw: [String: Double] = [
            "Tp1A": 52.4, "Tp1C": 61.8, "Tp1G": 58.1, "Tp1K": 64.3,
            "Te04": 47.2, "Te05": 49.9,
            "Tg0f": 55.6, "Tg0j": 57.0,
            "TH0a": 38.2, "TB0T": 31.5, "TB1T": 31.2,
            "TW0P": 41.0, "Ts0P": 33.4,
        ]
        let sensors = SensorCatalog.sensors(from: raw.map { ($0.key, $0.value) })
        let fans = [
            FanStatus(id: 0, current: 3120, minimum: 2317, maximum: 6800, isManual: true),
            FanStatus(id: 1, current: 3345, minimum: 2317, maximum: 6800, isManual: true),
        ]
        let now = Date()
        let history = (0..<450).map { i -> HistorySample in
            let t = Double(i)
            let load = 0.5 + 0.5 * sin(t / 40)
            let cpu = 44 + 20 * load + 2 * sin(t / 3)
            return HistorySample(date: now.addingTimeInterval(-Double(450 - i) * 2), values: [
                Aggregate.cpuHottest.sensorID: cpu,
                Aggregate.cpuAverage.sensorID: cpu - 7,
                Aggregate.gpuHottest.sensorID: cpu - 5 + 3 * cos(t / 15),
                Aggregate.ssdHottest.sensorID: 36 + 3 * load,
                Aggregate.batteryHottest.sensorID: 30 + load,
                "fan0": load > 0.6 ? 2317 + 3000 * (load - 0.6) / 0.4 : 0,
                "fan1": load > 0.6 ? 2400 + 3100 * (load - 0.6) / 0.4 : 0,
            ])
        }
        return Monitor(sensors: sensors, raw: raw, fans: fans, history: history)
    }

    // MARK: Rendering

    private static func snap(_ view: some View, name: String, title: String, dark: Bool, dir: URL) {
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(NSSize(width: 860, height: 620))
        // Off the visible displays, so nothing flashes on screen; the window server can
        // still composite and capture a window regardless of where it's positioned.
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        // Forms are List-backed, so `fittingSize` just echoes the current frame back
        // instead of measuring content. Grow the window to the tallest scroll view's
        // actual document height so long panes aren't cropped.
        let contentHeight = tallestDocumentHeight(in: controller.view)
        if contentHeight > 0 {
            window.setContentSize(NSSize(width: 860, height: contentHeight + 40))
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        if let image = windowImage(window) {
            let rep = NSBitmapImageRep(cgImage: image)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("\(name).png"))
                print("  \(name).png")
            }
        }
        window.orderOut(nil)
        window.close()
    }

    /// Tallest document view among the nested scroll views (List/Form is List-backed on
    /// macOS), so the window can be resized to show a pane's full content, uncropped.
    private static func tallestDocumentHeight(in view: NSView) -> CGFloat {
        var tallest: CGFloat = 0
        if let scrollView = view as? NSScrollView, let document = scrollView.documentView {
            tallest = document.frame.height
        }
        for subview in view.subviews {
            tallest = max(tallest, tallestDocumentHeight(in: subview))
        }
        return tallest
    }

    /// Captures one of our own windows through the window server, so AppKit-backed
    /// SwiftUI controls render exactly as on screen. Looked up at runtime because the
    /// symbol is no longer exposed in the SDK; capturing your own windows needs no permission.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let sym = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(sym, to: Fn.self)
        // kCGWindowListOptionIncludingWindow = 8, boundsIgnoreFraming = 1, bestResolution = 8
        return fn(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue()
    }
}
