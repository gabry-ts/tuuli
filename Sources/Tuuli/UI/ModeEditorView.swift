import PartitiUI
import SwiftUI
import TuuliCore

struct ModeEditorView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(HelperClient.self) private var helper
    @Environment(\.colorScheme) private var colorScheme
    let modeID: UUID
    /// Moves the window to another page, after duplicating or deleting this mode.
    let select: (SettingsView.Page) -> Void
    @State private var editingBattery = false
    @State private var nameDraft = ""
    @FocusState private var editingName: Bool

    private var mode: Mode {
        store.settings.modes.first { $0.id == modeID } ?? store.settings.modes[0]
    }

    private var isActive: Bool { store.settings.activeModeID == modeID }

    var body: some View {
        TuuliPane(title: mode.name, subtitle: mode.kind.summary, symbol: mode.kind.icon, color: AppAccent.tuuli.color) {
            if isActive {
                Badge("Active")
            } else {
                Button("Use This Mode") { store.settings.activeModeID = modeID }
                    .buttonStyle(PrimaryButtonStyle(height: PUI.Control.regular, fullWidth: false))
            }
        } content: {
            if !helper.isReady, mode.kind != .system {
                SettingsGroup {
                    SettingsRow("Fan control needs the helper",
                                subtitle: "A small background service that sets fan speeds. It needs your password once.") {
                        Button("Install…") { helper.install() }
                            .buttonStyle(PrimaryButtonStyle(height: PUI.Control.regular, fullWidth: false))
                    }
                }
            }

            FanConfigEditor(kind: mode.kind, config: binding(
                mode.hasBatterySettings && !mode.sameOnBattery && editingBattery ? \.battery : \.adapter
            ))

            if mode.hasBatterySettings, PowerSource.hasBattery {
                powerGroup
            }

            modeGroup
        }
        .onAppear { nameDraft = mode.name }
        .onChange(of: editingName) { _, editing in
            if !editing { commitName() }
        }
    }

    private var powerGroup: some View {
        let ink = Ink(colorScheme)
        let sources: [(value: Bool, title: LocalizedStringKey)] = [(false, "Power Adapter"), (true, "Battery")]
        return SettingsGroup("Power") {
            SettingsRow("Same settings on power adapter and battery") {
                HStack(spacing: PUI.Space.m) {
                    Text("Different on battery")
                        .font(PUI.Font.callout)
                        .foregroundStyle(ink.secondary)
                    Toggle("Different on battery", isOn: Binding(
                        get: { !mode.sameOnBattery },
                        set: { binding(\.sameOnBattery).wrappedValue = !$0 }
                    ))
                    .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
            }
            if !mode.sameOnBattery {
                SettingsRow("Editing", subtitle: "The settings above apply on this power source.") {
                    SegmentedPill(sources, selection: $editingBattery, height: PUI.Control.regular)
                }
            }
        }
    }

    private var modeGroup: some View {
        let kinds = FanMode.allCases.map { (value: $0, title: $0.title) }
        return SettingsGroup("Mode", footer: mode.isBuiltIn ? "Built-in modes can be renamed and duplicated, but not deleted." : nil) {
            SettingsRow("Name") {
                TextField("Name", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .focused($editingName)
                    .onSubmit(commitName)
            }
            if !mode.isBuiltIn {
                SettingsRow("Type") {
                    SegmentedPill(kinds, selection: binding(\.kind), height: PUI.Control.regular)
                }
            }
            SettingsRow("Duplicate", subtitle: "Copies this mode into a new custom mode.") {
                Button("Duplicate") {
                    if let id = store.duplicateMode(modeID) { select(.mode(id)) }
                }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
            }
            if !mode.isBuiltIn {
                SettingsRow("Delete") {
                    Button("Delete Mode", role: .destructive) {
                        select(.pane(.overview))
                        store.deleteMode(modeID)
                    }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
            }
        }
    }

    /// Renames the mode, or puts the name back when it was left empty.
    private func commitName() {
        store.renameMode(modeID, to: nameDraft)
        nameDraft = mode.name
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
    @Environment(\.colorScheme) private var colorScheme
    let kind: FanMode
    @Binding var config: FanConfig

    var body: some View {
        switch kind {
        case .system:
            SettingsGroup {
                HStack(spacing: PUI.Space.l) {
                    Image(systemName: "leaf")
                        .font(.system(size: 18))
                        .foregroundStyle(Heat.color(40))
                    Text("Nothing to set up. macOS decides when the fans spin, and Tuuli keeps watching the temperatures.")
                        .font(PUI.Font.body)
                        .foregroundStyle(Ink(colorScheme).secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(PUI.Space.l)
            }
        case .manual:
            manualGroup
        case .boost:
            rulesGroup
            behaviorGroup(showsHysteresis: true)
        case .curve:
            SettingsGroup("Curve", footer: "Drag the points to shape the curve.") {
                CurveEditor(points: $config.curve, sensor: $config.curveSensor, current: monitor.value(config.curveSensor))
                    .padding(PUI.Space.l)
            }
            behaviorGroup(showsHysteresis: false)
        }
    }

    private var manualGroup: some View {
        let ink = Ink(colorScheme)
        return SettingsGroup("Speed") {
            VStack(alignment: .leading, spacing: PUI.Space.l) {
                BigNumber("\(Int(config.manualPercent))", unit: "%",
                          font: .system(size: 52, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: config.manualPercent))
                    .animation(.smooth, value: config.manualPercent)
                PUISlider(value: Binding(
                    get: { config.manualPercent },
                    set: { config.manualPercent = ($0 / 5).rounded() * 5 }
                ), in: 0...100)
                HStack(spacing: PUI.Space.xl) {
                    ForEach(monitor.fans) { fan in
                        let rpm = fan.rpm(forPercent: config.manualPercent)
                        HStack(spacing: PUI.Space.xs) {
                            RowSymbol("fan.fill", color: rpm > 0 ? AppAccent.tuuli.legible(colorScheme) : nil)
                            Text(verbatim: "\(fan.name) · \(Int(rpm)) rpm")
                                .font(PUI.Font.callout)
                                .monospacedDigit()
                                .foregroundStyle(ink.secondary)
                        }
                    }
                }
            }
            .padding(PUI.Space.l)
        }
    }

    private var rulesGroup: some View {
        SettingsGroup("Rules") {
            ForEach($config.rules) { $rule in
                RuleSentence(rule: $rule) {
                    config.rules.removeAll { $0.id == rule.id }
                }
            }
            HStack {
                Button {
                    config.rules.append(BoostRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 80, percent: 100))
                } label: {
                    Label("Add Rule", systemImage: "plus").labelStyle(TightLabelStyle())
                }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                Spacer()
            }
            .padding(PUI.Space.l)
        }
    }

    private func behaviorGroup(showsHysteresis: Bool) -> some View {
        SettingsGroup("Behavior") {
            SettingsRow("Ramp up over", subtitle: "Fans speed up gradually instead of jumping.") {
                StepperValue(config.rampSeconds == 0 ? "Instantly" : "\(Int(config.rampSeconds)) seconds",
                             value: $config.rampSeconds, in: 0...60)
            }
            if showsHysteresis {
                SettingsRow("Let go once it cools by") {
                    StepperValue("\(Int(config.hysteresis))°", value: $config.hysteresis, in: 0...15)
                }
            }
        }
    }
}

/// A boost rule written as a sentence: "When CPU Hottest reaches 65° run fans at 100%".
private struct RuleSentence: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(\.colorScheme) private var colorScheme
    @Binding var rule: BoostRule
    let remove: () -> Void

    var body: some View {
        let unit = store.settings.unit
        let ink = Ink(colorScheme)
        let now = monitor.value(rule.sensor)
        let firing = rule.isEnabled && (now ?? 0) >= rule.threshold
        VStack(alignment: .leading, spacing: PUI.Space.m) {
            HStack(spacing: PUI.Space.m) {
                Toggle("Enabled", isOn: $rule.isEnabled)
                    .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
                Text("When")
                SensorField(title: "Sensor", selection: $rule.sensor)
                Text("reaches")
                StepperValue(unit.short(rule.threshold), value: $rule.threshold, in: 30...110,
                             color: PUI.legible(Heat.color(rule.threshold), colorScheme))
                Spacer()
                Button(action: remove) {
                    Image(systemName: "trash")
                        .foregroundStyle(ink.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove Rule")
            }
            HStack(spacing: PUI.Space.m) {
                Text("run fans at")
                PUISlider(value: Binding(
                    get: { rule.percent },
                    set: { rule.percent = ($0 / 5).rounded() * 5 }
                ), in: 0...100)
                Text(verbatim: "\(Int(rule.percent))%")
                    .monospacedDigit()
                    .foregroundStyle(ink.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: PUI.Space.s) {
                Circle()
                    .fill(firing ? Heat.color(now) : ink.tertiary)
                    .frame(width: 7, height: 7)
                Text(firing ? "Boosting now, at \(unit.short(now))" : "Now \(unit.short(now))")
                    .font(PUI.Font.caption)
                    .foregroundStyle(ink.secondary)
            }
        }
        .font(PUI.Font.body)
        .foregroundStyle(ink.primary)
        .padding(PUI.Space.l)
        .opacity(rule.isEnabled ? 1 : 0.55)
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
