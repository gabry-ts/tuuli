import Charts
import SwiftUI
import TuuliCore

struct ModeEditorView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(HelperClient.self) private var helper
    let modeID: UUID
    @State private var editingBattery = false

    private var mode: Mode {
        store.settings.modes.first { $0.id == modeID } ?? store.settings.modes[0]
    }

    var body: some View {
        Form {
            if !helper.isReady, mode.kind != .system {
                Section {
                    Label("Fan control needs the helper. Install it from General.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            Section {
                TextField("Name", text: binding(\.name))
                if !mode.isBuiltIn {
                    Picker("Type", selection: binding(\.kind)) {
                        ForEach(FanMode.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Active", isOn: Binding(
                    get: { store.settings.activeModeID == modeID },
                    set: { if $0 { store.settings.activeModeID = modeID } }
                ))
                .disabled(store.settings.activeModeID == modeID)
            } footer: {
                Text(mode.kind.summary)
                    .foregroundStyle(.secondary)
            }

            if mode.hasBatterySettings, PowerSource.hasBattery {
                Section {
                    Toggle("Same settings on battery", isOn: binding(\.sameOnBattery))
                    if !mode.sameOnBattery {
                        Picker("Editing", selection: $editingBattery) {
                            Text("Power Adapter").tag(false)
                            Text("Battery").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text("Now on \(monitor.isOnBattery ? "battery" : "power adapter").")
                        .foregroundStyle(.secondary)
                }
            }

            FanConfigEditor(kind: mode.kind, config: binding(
                mode.hasBatterySettings && !mode.sameOnBattery && editingBattery ? \.battery : \.adapter
            ))
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Mode, T>) -> Binding<T> {
        Binding(
            get: { mode[keyPath: keyPath] },
            set: { value in
                if let index = store.settings.index(of: modeID) {
                    store.settings.modes[index][keyPath: keyPath] = value
                }
            }
        )
    }
}

struct FanConfigEditor: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    let kind: FanMode
    @Binding var config: FanConfig

    var body: some View {
        switch kind {
        case .system:
            EmptyView()
        case .manual:
            Section("Speed") {
                PercentSlider(title: "All fans", percent: $config.manualPercent)
                if let fan = monitor.fans.first {
                    LabeledContent("Target", value: "\(Int(fan.rpm(forPercent: config.manualPercent))) rpm")
                }
            }
        case .boost:
            rulesSection
            rampSection(showsHysteresis: true)
        case .curve:
            Section("Curve") {
                SensorPicker(title: "Sensor", selection: $config.curveSensor)
                CurveEditor(points: $config.curve, current: monitor.value(config.curveSensor))
            }
            rampSection(showsHysteresis: false)
        }
    }

    private var rulesSection: some View {
        Section {
            ForEach($config.rules) { $rule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("Enabled", isOn: $rule.isEnabled)
                            .labelsHidden()
                        SensorPicker(title: "When", selection: $rule.sensor)
                        Button(role: .destructive) {
                            config.rules.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TemperatureField(title: "reaches", celsius: $rule.threshold, unit: store.settings.unit)
                    PercentSlider(title: "run fans at", percent: $rule.percent)
                }
                .padding(.vertical, 4)
            }
            Button {
                config.rules.append(BoostRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 80, percent: 100))
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
        } header: {
            Text("Rules")
        }
    }

    private func rampSection(showsHysteresis: Bool) -> some View {
        Section("Behavior") {
            Stepper(value: $config.rampSeconds, in: 0...60, step: 1) {
                LabeledContent("Ramp time", value: config.rampSeconds == 0 ? "Instant" : "\(Int(config.rampSeconds)) s")
            }
            if showsHysteresis {
                Stepper(value: $config.hysteresis, in: 0...15, step: 1) {
                    LabeledContent("Release below threshold by", value: "\(Int(config.hysteresis))°")
                }
            }
        }
    }
}

/// Chart preview of the curve plus an editable list of its points.
struct CurveEditor: View {
    @Environment(SettingsStore.self) private var store
    @Binding var points: [CurvePoint]
    let current: Double?

    var body: some View {
        let unit = store.settings.unit
        let sorted = points.sorted { $0.temperature < $1.temperature }
        Chart {
            ForEach(sorted) { point in
                LineMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
                PointMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
            }
            if let current {
                RuleMark(x: .value("Now", unit.convert(current)))
                    .foregroundStyle(.orange)
                    .annotation(position: .top, alignment: .leading) {
                        Text(unit.short(current)).font(.caption).foregroundStyle(.orange)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: unit.convert(20)...unit.convert(110))
        .chartXAxisLabel(unit.symbol)
        .chartYAxisLabel("%")
        .frame(height: 180)
        .padding(.vertical, 4)

        ForEach($points) { $point in
            HStack(spacing: 16) {
                TemperatureField(title: "At", celsius: $point.temperature, unit: unit, range: 20...110)
                    .frame(maxWidth: 200)
                PercentSlider(title: "", percent: $point.percent)
                Button(role: .destructive) {
                    points.removeAll { $0.id == point.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(points.count <= 2)
            }
        }
        Button {
            let last = sorted.last
            points.append(CurvePoint(temperature: min((last?.temperature ?? 60) + 5, 110), percent: last?.percent ?? 50))
        } label: {
            Label("Add Point", systemImage: "plus")
        }
    }
}

extension FanMode {
    var summary: String {
        switch self {
        case .system: "macOS controls the fans. Tuuli only monitors."
        case .boost: "Fans stay under system control until a rule's sensor reaches its threshold, then run at that rule's speed. The fastest active rule wins."
        case .curve: "Fan speed follows the sensor along the curve. At 0% the system takes over, so fans can still idle."
        case .manual: "Fans run at a fixed speed, whatever the temperature."
        }
    }
}
