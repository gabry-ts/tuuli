import PartitiUI
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

    /// The menu bar item is an NSStatusItem owned by the app delegate; this scene only
    /// satisfies SwiftUI's need for one.
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = SettingsStore()
    let monitor = Monitor()
    let engine = FanEngine()
    let helper = HelperClient()
    let updater = Updater()
    private let notifier = Notifier()
    private let logger = CSVLogger()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var observedPollInterval: Double = 0
    private var statusItem: StatusItemController?
    private var didOfferHelperReinstall = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstLaunch = !SettingsStore.hasSavedSettings
        store.saveNow()

        // Deferred so the alert never blocks launch.
        helper.onNeedsReinstall = { [weak self] in
            Task { @MainActor in self?.offerHelperReinstall() }
        }
        helper.refresh()
        statusItem = StatusItemController { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(
                MenuContent(
                    openSettings: { [weak self] in
                        self?.statusItem?.closePopover()
                        self?.openSettingsWindow()
                    },
                    applyNow: { [weak self] in self?.applyFans() }
                )
                .environment(store)
                .environment(monitor)
                .environment(engine)
                .environment(helper)
                .environment(updater)
            )
        } render: { [store, monitor] in
            StatusImage.content(store: store, monitor: monitor)
        }
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
        notifier.check(settings: settings, monitor: monitor)
        logger.log(settings: settings.logging, monitor: monitor)
    }

    /// After an app update the installed helper may be older, or signed by a different
    /// team, and would refuse the app. Offers to reinstall it once per launch.
    private func offerHelperReinstall() {
        guard !didOfferHelperReinstall else { return }
        didOfferHelperReinstall = true
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Update the fan control helper?"
        alert.informativeText = "This version of Tuuli needs a newer fan control helper. Until it's updated, macOS stays in charge of the fans. It needs your password once."
        alert.addButton(withTitle: "Update Helper…")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            helper.install()
        }
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
        window.delegate = self
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
            .environment(updater)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Tuuli"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // Partiti UI's sidebar runs under a clear title bar, past the traffic lights.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(PUI.Window.dashboard)
        window.minSize = PUI.Window.dashboardMin
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Closed windows are torn down rather than kept around, so their live charts stop
    /// drawing in the background.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.contentViewController = nil
        if window === settingsWindow { settingsWindow = nil }
        if window === onboardingWindow { onboardingWindow = nil }
    }
}
