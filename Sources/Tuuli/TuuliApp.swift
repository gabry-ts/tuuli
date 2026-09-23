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
            MenuBarLabel(store: appDelegate.store, monitor: appDelegate.monitor)
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
    private let notifier = Notifier()
    private let logger = CSVLogger()
    private var settingsWindow: NSWindow?
    private var observedPollInterval: Double = 0
    private var lastOnBattery: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = !SettingsStore.hasSavedSettings
        store.saveNow()

        helper.refresh()
        monitor.onSample = { [weak self] in self?.tick() }
        observedPollInterval = store.settings.pollInterval
        monitor.start(interval: observedPollInterval)

        if isFirstLaunch {
            LoginItem.register()
            openSettingsWindow()
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
        // A hand-picked profile lasts until the power source changes.
        if let lastOnBattery, lastOnBattery != monitor.isOnBattery {
            store.settings.overrideProfileID = nil
        }
        lastOnBattery = monitor.isOnBattery
        let settings = store.settings
        if settings.pollInterval != observedPollInterval {
            observedPollInterval = settings.pollInterval
            monitor.schedule(interval: observedPollInterval)
        }
        engine.tick(monitor: monitor, settings: settings, helper: helper)
        notifier.check(settings: settings, monitor: monitor)
        logger.log(settings: settings.logging, monitor: monitor)
    }

    /// Re-evaluates the fans immediately after a change from the menu bar.
    func applyFans() {
        engine.tick(monitor: monitor, settings: store.settings, helper: helper)
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
        controller.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: controller)
        window.title = "Tuuli"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 860, height: 620))
        window.minSize = NSSize(width: 760, height: 540)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
