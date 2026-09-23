import SwiftUI
import TuuliCore

@main
struct TuuliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-snapshots"), args.indices.contains(i + 1) {
            exit(MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: args[i + 1])) })
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                openSettings: { appDelegate.openSettingsWindow() },
                applyNow: { appDelegate.applyFans() }
            )
                .environment(appDelegate.store)
                .environment(appDelegate.monitor)
                .environment(appDelegate.engine)
                .environment(appDelegate.helper)
        } label: {
            MenuBarLabel(store: appDelegate.store, monitor: appDelegate.monitor, spinner: appDelegate.spinner)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SettingsStore()
    let monitor = Monitor()
    let engine = FanEngine()
    let helper = HelperClient()
    let spinner = IconSpinner()
    private let notifier = Notifier()
    private let logger = CSVLogger()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var observedPollInterval: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = !SettingsStore.hasSavedSettings
        store.saveNow()

        helper.refresh()
        monitor.onSample = { [weak self] in self?.tick() }
        observedPollInterval = store.settings.pollInterval
        monitor.start(interval: observedPollInterval)

        if isFirstLaunch {
            LoginItem.register()
            openOnboardingWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.release(helper: helper)
        monitor.stop()
        store.saveNow()
    }

    /// Reopening the app (Spotlight, Finder) brings settings back, even with the menu bar
    /// icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return true
    }

    private func tick() {
        let settings = store.settings
        if settings.pollInterval != observedPollInterval {
            observedPollInterval = settings.pollInterval
            monitor.schedule(interval: observedPollInterval)
        }
        engine.tick(monitor: monitor, settings: settings, helper: helper)
        let spinning = settings.menuBar.spinsIcon && settings.menuBar.items.contains(.icon)
        let fastest = monitor.fans.max { $0.current < $1.current }
        spinner.update(percent: spinning && (fastest?.current ?? 0) > 0 ? fastest?.percent : nil)
        notifier.check(settings: settings, monitor: monitor)
        logger.log(settings: settings.logging, monitor: monitor)
    }

    /// Re-evaluates the fans immediately after a change from the menu bar.
    func applyFans() {
        engine.tick(monitor: monitor, settings: store.settings, helper: helper)
    }

    func openOnboardingWindow() {
        NSApp.activate()
        let view = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
        .environment(store)
        .environment(helper)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func openSettingsWindow() {
        NSApp.activate()
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView()
            .environment(store)
            .environment(monitor)
            .environment(engine)
            .environment(helper)
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: controller)
        window.title = "Tuuli"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // One continuous surface: the sky runs under a clear title bar, and each page
        // carries its own large title.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.minSize = NSSize(width: 920, height: 560)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
