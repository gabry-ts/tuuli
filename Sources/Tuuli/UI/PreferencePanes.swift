import SwiftUI
import TuuliCore

struct AlertsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                ForEach($store.settings.alerts) { $rule in
                    HStack {
                        Toggle("Enabled", isOn: $rule.isEnabled)
                            .labelsHidden()
                        SensorPicker(title: "Notify when", selection: $rule.sensor)
                        Button(role: .destructive) {
                            store.settings.alerts.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TemperatureField(title: "reaches", celsius: $rule.threshold, unit: store.settings.unit)
                }
                Button {
                    store.settings.alerts.append(AlertRule(sensor: Aggregate.hottest.sensorID, threshold: 90))
                } label: {
                    Label("Add Alert", systemImage: "plus")
                }
            } header: {
                Text("Alerts")
            }

            Section("Delivery") {
                Stepper(value: $store.settings.alertCooldownMinutes, in: 1...60, step: 1) {
                    LabeledContent("Repeat at most every", value: "\(Int(store.settings.alertCooldownMinutes)) min")
                }
                Toggle("Play sound", isOn: $store.settings.alertSound)
            }
        }
        .formStyle(.grouped)
    }
}

struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var newSensor = Aggregate.hottest.sensorID

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                statusItems
                HStack {
                    Button("Add Temperature") {
                        store.settings.menuBar.items.append(.temperature(Aggregate.cpuHottest.sensorID))
                    }
                    if !store.settings.menuBar.items.contains(.icon) {
                        Button("Add Icon") { store.settings.menuBar.items.append(.icon) }
                    }
                    if !store.settings.menuBar.items.contains(.fanSpeed) {
                        Button("Add Fan Speed") { store.settings.menuBar.items.append(.fanSpeed) }
                    }
                }
            } header: {
                Text("Status Item")
            } footer: {
                Text("Shown left to right. With nothing in the list, the icon is shown.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(Array(store.settings.popover.sections.enumerated()), id: \.element.section) { index, entry in
                    HStack {
                        Toggle(entry.section.title, isOn: $store.settings.popover.sections[index].isEnabled)
                        Spacer()
                        ReorderButtons(items: $store.settings.popover.sections, index: index)
                    }
                }
            } header: {
                Text("Popover")
            } footer: {
                Text("Shown top to bottom. The mode picker adds a speed slider when the active mode is manual.")
                    .foregroundStyle(.secondary)
            }

            Section("Popover Temperatures") {
                temperatureList
            }

            Section("Popover Chart") {
                SensorPicker(title: "Sensor", selection: $store.settings.popover.chartSensor)
                Picker("Window", selection: $store.settings.popover.chartMinutes) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("60 min").tag(60)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusItems: some View {
        @Bindable var store = store
        ForEach(Array(store.settings.menuBar.items.enumerated()), id: \.offset) { index, item in
            HStack {
                switch item {
                case .icon:
                    Label("Icon", systemImage: "fan.fill")
                case .fanSpeed:
                    Label("Fan speed", systemImage: "gauge.with.dots.needle.33percent")
                case .temperature(let sensor):
                    SensorPicker(title: "Temperature", selection: Binding(
                        get: { sensor },
                        set: { store.settings.menuBar.items[index] = .temperature($0) }
                    ))
                    .fixedSize()
                }
                Spacer()
                ReorderButtons(items: $store.settings.menuBar.items, index: index, removable: true)
            }
        }
    }

    @ViewBuilder
    private var temperatureList: some View {
        @Bindable var store = store
        ForEach(Array(store.settings.popover.temperatureSensors.enumerated()), id: \.offset) { index, _ in
            HStack {
                SensorPicker(title: "", selection: $store.settings.popover.temperatureSensors[index])
                    .labelsHidden()
                    .fixedSize()
                Spacer()
                ReorderButtons(items: $store.settings.popover.temperatureSensors, index: index, removable: true)
            }
        }
        HStack {
            SensorPicker(title: "Add", selection: $newSensor)
            Button("Add") {
                store.settings.popover.temperatureSensors.append(newSensor)
            }
        }
    }
}

/// Move up, move down and optionally remove, for rows of an ordered list.
struct ReorderButtons<Element>: View {
    @Binding var items: [Element]
    let index: Int
    var removable = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                items.swapAt(index, index - 1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(index == 0)
            Button {
                items.swapAt(index, index + 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(index == items.count - 1)
            if removable {
                Button(role: .destructive) {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle")
                }
            }
        }
        .buttonStyle(.borderless)
    }
}

struct LoggingView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Log to CSV", isOn: $store.settings.logging.isEnabled)
                Stepper(value: $store.settings.logging.interval, in: 1...300, step: 1) {
                    LabeledContent("Every", value: "\(Int(store.settings.logging.interval)) s")
                }
                LabeledContent("Folder") {
                    HStack {
                        Text(store.settings.logging.folderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose…", action: chooseFolder)
                        Button("Show") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: store.settings.logging.folderPath))
                        }
                    }
                }
            } footer: {
                Text("One file per day, named Tuuli-<date>.csv, with every sensor and fan as a column.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
    @State private var launchAtLogin = LoginItem.status == .enabled

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                LabeledContent("Status") {
                    Text(helperStatus)
                        .foregroundStyle(helper.isReady ? .green : .secondary)
                }
                HStack {
                    switch helper.status {
                    case .notInstalled, .unreachable:
                        Button("Install Helper…") { helper.install() }
                    case .outdated:
                        Button("Update Helper…") { helper.install() }
                    case .ready, .checking:
                        EmptyView()
                    }
                    if helper.status != .notInstalled {
                        Button("Uninstall Helper…") { helper.uninstall() }
                    }
                }
                if let error = helper.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Fan Control Helper")
            } footer: {
                Text("Writing fan speeds needs root. The helper is a small background service that only sets fan speeds, and hands the fans back to macOS if Tuuli quits, crashes or the Mac sleeps.")
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        enabled ? LoginItem.register() : LoginItem.unregister()
                    }
                if LoginItem.status == .requiresApproval {
                    Button("Approve in System Settings…") { LoginItem.openSystemSettings() }
                }
                Picker("Temperature unit", selection: $store.settings.unit) {
                    Text("Celsius").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                }
                Picker("Update every", selection: $store.settings.pollInterval) {
                    Text("1 s").tag(1.0)
                    Text("2 s").tag(2.0)
                    Text("3 s").tag(3.0)
                    Text("5 s").tag(5.0)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { helper.refresh() }
    }

    private var helperStatus: String {
        switch helper.status {
        case .notInstalled: "Not installed"
        case .checking: "Checking…"
        case .ready: "Running"
        case .outdated(let version): "Outdated (v\(version))"
        case .unreachable: "Installed, not responding"
        }
    }
}
