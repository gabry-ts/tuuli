import PartitiUI
import SwiftUI
import TuuliCore

struct AlertsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TuuliPane(.alerts, subtitle: "A notification when a sensor gets too hot.") {
            SettingsGroup("Alerts") {
                ForEach($store.settings.alerts) { $rule in
                    AlertRow(rule: $rule) {
                        store.settings.alerts.removeAll { $0.id == rule.id }
                    }
                }
                HStack {
                    Button {
                        store.settings.alerts.append(AlertRule(sensor: Aggregate.hottest.sensorID, threshold: 90))
                    } label: {
                        Label("Add Alert", systemImage: "plus").labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    Spacer()
                }
                .padding(PUI.Space.l)
            }

            SettingsGroup("Delivery") {
                SettingsRow("Repeat at most every") {
                    StepperValue("\(Int(store.settings.alertCooldownMinutes)) min",
                                 value: $store.settings.alertCooldownMinutes, in: 1...60)
                }
                SwitchRow("Play sound", isOn: $store.settings.alertSound)
            }
        }
    }
}

/// One alert as a sentence: "Notify when CPU Hottest reaches 95.0 °C".
private struct AlertRow: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Binding var rule: AlertRule
    let remove: () -> Void

    var body: some View {
        let ink = Ink(colorScheme)
        HStack(spacing: PUI.Space.m) {
            Toggle("Enabled", isOn: $rule.isEnabled)
                .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
            Text("Notify when")
            SensorField(title: "Notify when", selection: $rule.sensor)
            Text("reaches")
            StepperValue(store.settings.unit.format(rule.threshold), value: $rule.threshold, in: 30...110)
            Spacer()
            Button(action: remove) {
                Image(systemName: "trash")
                    .foregroundStyle(ink.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove Alert")
        }
        .font(PUI.Font.body)
        .foregroundStyle(ink.primary)
        .padding(PUI.Space.l)
    }
}

struct LoggingView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TuuliPane(.logging, subtitle: "Every reading written to a CSV file, for later.") {
            SettingsGroup("CSV", footer: "One file per day, named Tuuli-<date>.csv, with every sensor and fan as a column.") {
                SwitchRow("Log to CSV", isOn: $store.settings.logging.isEnabled)
                SettingsRow("Every") {
                    StepperValue("\(Int(store.settings.logging.interval)) s", value: $store.settings.logging.interval, in: 1...300)
                }
                SettingsRow("Folder", subtitle: store.settings.logging.folderPath) {
                    HStack(spacing: PUI.Space.s) {
                        Button("Choose…", action: chooseFolder)
                        Button("Show") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: store.settings.logging.folderPath))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: store.settings.logging.folderPath)
        if panel.runModal() == .OK, let url = panel.url {
            store.settings.logging.folderPath = url.path
        }
    }
}

struct GeneralView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(HelperClient.self) private var helper
    @Environment(\.colorScheme) private var colorScheme
    @State private var launchAtLogin = LoginItem.status == .enabled

    var body: some View {
        @Bindable var store = store
        let ink = Ink(colorScheme)
        let units: [(value: TemperatureUnit, title: LocalizedStringKey)] = [(.celsius, "Celsius"), (.fahrenheit, "Fahrenheit")]
        let intervals: [(value: Double, title: LocalizedStringKey)] = [(1, "1 s"), (2, "2 s"), (3, "3 s"), (5, "5 s")]
        TuuliPane(.general, subtitle: "The fan control helper, startup and readings.") {
            SettingsGroup("Fan Control Helper",
                          footer: "Writing fan speeds needs root. The helper is a small background service that only sets fan speeds, and hands the fans back to macOS if Tuuli quits, crashes or the Mac sleeps.") {
                SettingsRow("Status") {
                    Text(helperStatus)
                        .font(PUI.Font.callout)
                        .foregroundStyle(helper.isReady ? ink.green : ink.secondary)
                }
                SettingsRow("Helper") {
                    HStack(spacing: PUI.Space.s) {
                        switch helper.status {
                        case .notInstalled, .unreachable:
                            Button("Install Helper…") { helper.install() }
                                .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false))
                        case .outdated, .incompatible:
                            Button("Update Helper…") { helper.install() }
                                .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false))
                        case .ready, .checking:
                            EmptyView()
                        }
                        if helper.status != .notInstalled {
                            Button("Uninstall Helper…") { helper.uninstall() }
                                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                        }
                    }
                }
                if let error = helper.lastError {
                    Text(error)
                        .font(PUI.Font.caption)
                        .foregroundStyle(ink.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(PUI.Space.l)
                }
            }

            SettingsGroup("General") {
                SwitchRow("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        enabled ? LoginItem.register() : LoginItem.unregister()
                    }
                if LoginItem.status == .requiresApproval {
                    SettingsRow("Login item needs approval") {
                        Button("Approve in System Settings…") { LoginItem.openSystemSettings() }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
                SettingsRow("Temperature unit") {
                    SegmentedPill(units, selection: $store.settings.unit, height: PUI.Control.regular)
                }
                SettingsRow("Update every") {
                    SegmentedPill(intervals, selection: $store.settings.pollInterval, height: PUI.Control.regular)
                }
            }
        }
        .onAppear { helper.refresh() }
    }

    private var helperStatus: String {
        switch helper.status {
        case .notInstalled: "Not installed"
        case .checking: "Checking…"
        case .ready: "Running"
        case .outdated(let version): "Outdated (v\(version))"
        case .incompatible: "Needs reinstalling"
        case .unreachable: "Installed, not responding"
        }
    }
}

/// About: Partiti UI's pane with Tuuli's icon, version, updates and a way to support it.
struct AboutView: View {
    @Environment(Updater.self) private var updater

    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }()

    var body: some View {
        @Bindable var updater = updater
        ScrollView {
            AboutPane(
                brand: PartitiBrand(accent: .tuuli,
                                    tagline: "Temperatures and fans in your menu bar",
                                    coffeeLine: "Tuuli is free. If it keeps your Mac cool, you can buy me a coffee.",
                                    icon: Image(nsImage: NSApp.applicationIconImage)),
                version: Self.version,
                checksAutomatically: $updater.automaticallyChecksForUpdates,
                onCheckForUpdates: { updater.checkForUpdates() },
                canCheckForUpdates: updater.canCheckForUpdates,
                onBuyMeACoffee: { NSWorkspace.shared.open(Links.buyMeACoffee) })
                .padding(.top, 44)
                .padding(.horizontal, PUI.Space.xxl)
                .padding(.bottom, PUI.Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
