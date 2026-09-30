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

    private var isActive: Bool { store.settings.activeModeID == modeID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !helper.isReady, mode.kind != .system {
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fan control needs the helper")
                                    .font(.headline)
                                Text("A small background service that sets fan speeds. It needs your password once.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Install…") { helper.install() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.sky)
                        }
                    }
                }

                if mode.hasBatterySettings, PowerSource.hasBattery {
                    Card(padding: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: monitor.isOnBattery ? "battery.75percent" : "bolt.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            if mode.sameOnBattery {
                                Text("Same settings on power adapter and battery")
                            } else {
                                Picker("Editing", selection: $editingBattery) {
                                    Text("Power Adapter").tag(false)
                                    Text("Battery").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .fixedSize()
                            }
                            Spacer()
                            Toggle("Different on battery", isOn: Binding(
                                get: { !mode.sameOnBattery },
                                set: { binding(\.sameOnBattery).wrappedValue = !$0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                }

                FanConfigEditor(kind: mode.kind, config: binding(
                    mode.hasBatterySettings && !mode.sameOnBattery && editingBattery ? \.battery : \.adapter
                ))
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AirBackground())
    }

    private var header: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Image(systemName: mode.kind.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Theme.sky.gradient, in: .rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Name", text: binding(\.name))
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(mode.isBuiltIn ? "Built-in \(mode.kind.title) mode" : "Custom \(mode.kind.title) mode")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Theme.sky)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.sky.opacity(0.12), in: .capsule)
                    } else {
                        Button("Use This Mode") { store.settings.activeModeID = modeID }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.sky)
                    }
                }
                if !mode.isBuiltIn {
                    Picker("Type", selection: binding(\.kind)) {
                        ForEach(FanMode.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Text(mode.kind.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "leaf")
                        .font(.title2)
                        .foregroundStyle(Theme.heat(40))
                    Text("Nothing to set up. macOS decides when the fans spin, and Tuuli keeps watching the temperatures.")
                        .foregroundStyle(.secondary)
                }
            }
        case .manual:
            manualCard
        case .boost:
            rulesCard
            behaviorCard(showsHysteresis: true)
        case .curve:
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    CurveEditor(points: $config.curve, sensor: $config.curveSensor, current: monitor.value(config.curveSensor))
                    Text("Drag the points to shape the curve.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            behaviorCard(showsHysteresis: false)
        }
    }

    private var manualCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                CardTitle(title: "Speed", systemImage: "slider.horizontal.3")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(Int(config.manualPercent))")
                        .font(.system(size: 52, weight: .light, design: .rounded))
                        .contentTransition(.numericText(value: config.manualPercent))
                        .animation(.smooth, value: config.manualPercent)
                    Text("%")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $config.manualPercent, in: 0...100, step: 5)
                    .tint(Theme.sky)
                HStack(spacing: 20) {
                    ForEach(monitor.fans) { fan in
                        Label {
                            Text(verbatim: "\(fan.name) · \(Int(fan.rpm(forPercent: config.manualPercent))) rpm")
                        } icon: {
                            FanGlyph(rpm: fan.rpm(forPercent: config.manualPercent), size: 14)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var rulesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(title: "Rules", systemImage: "list.bullet")
                ForEach($config.rules) { $rule in
                    RuleSentence(rule: $rule) {
                        config.rules.removeAll { $0.id == rule.id }
                    }
                }
                Button {
                    config.rules.append(BoostRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 80, percent: 100))
                } label: {
                    Label("Add Rule", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.sky)
            }
        }
    }

    private func behaviorCard(showsHysteresis: Bool) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(title: "Behavior", systemImage: "wind")
                Stepper(value: $config.rampSeconds, in: 0...60, step: 1) {
                    HStack {
                        Text("Ramp up over")
                        Spacer()
                        Text(config.rampSeconds == 0 ? "Instantly" : "\(Int(config.rampSeconds)) seconds")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                if showsHysteresis {
                    Stepper(value: $config.hysteresis, in: 0...15, step: 1) {
                        HStack {
                            Text("Let go once it cools by")
                            Spacer()
                            Text(verbatim: "\(Int(config.hysteresis))°")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// A boost rule written as a sentence: "When CPU Hottest reaches 65° run fans at 100%".
private struct RuleSentence: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Binding var rule: BoostRule
    let remove: () -> Void

    var body: some View {
        let unit = store.settings.unit
        let now = monitor.value(rule.sensor)
        let firing = rule.isEnabled && (now ?? 0) >= rule.threshold
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Toggle("Enabled", isOn: $rule.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Text("When")
                SensorPicker(title: "Sensor", selection: $rule.sensor)
                    .labelsHidden()
                    .fixedSize()
                Text("reaches")
                Stepper(value: $rule.threshold, in: 30...110, step: 1) {
                    Text(verbatim: unit.short(rule.threshold))
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.heat(rule.threshold))
                }
                .fixedSize()
                Spacer()
                Button(action: remove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text("run fans at")
                Slider(value: $rule.percent, in: 0...100, step: 5)
                    .tint(Theme.sky)
                Text(verbatim: "\(Int(rule.percent))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(firing ? Theme.heat(now) : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(firing ? "Boosting now, at \(unit.short(now))" : "Now \(unit.short(now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.primary.opacity(0.04), in: .rect(cornerRadius: 12))
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
