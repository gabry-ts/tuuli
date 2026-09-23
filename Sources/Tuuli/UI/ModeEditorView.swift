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
                    HStack {
                        CardTitle(title: "Curve", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        Spacer()
                        SensorPicker(title: "Follows", selection: $config.curveSensor)
                            .fixedSize()
                    }
                    CurveEditor(points: $config.curve, current: monitor.value(config.curveSensor))
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
                            SpinningFan(rpm: fan.rpm(forPercent: config.manualPercent), size: 14)
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

/// The curve as a chart whose points can be dragged, with fine-tuning rows below.
struct CurveEditor: View {
    @Environment(SettingsStore.self) private var store
    @Binding var points: [CurvePoint]
    let current: Double?
    @State private var draggingID: UUID?
    @State private var showsValues = false

    var body: some View {
        let unit = store.settings.unit
        let sorted = points.sorted { $0.temperature < $1.temperature }
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(sorted) { point in
                    AreaMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
                        .foregroundStyle(.linearGradient(colors: [Theme.sky.opacity(0.28), Theme.sky.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
                        .foregroundStyle(Theme.sky)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                ForEach(sorted) { point in
                    PointMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
                        .symbol {
                            Circle()
                                .fill(.white)
                                .stroke(Theme.sky, lineWidth: 2.5)
                                .frame(width: draggingID == point.id ? 18 : 13)
                                .shadow(color: Theme.sky.opacity(0.4), radius: draggingID == point.id ? 6 : 0)
                        }
                }
                if let current {
                    RuleMark(x: .value("Now", unit.convert(current)))
                        .foregroundStyle(Theme.heat(current).opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .center) {
                            Text(verbatim: "Now \(unit.short(current))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.heat(current))
                        }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXScale(domain: unit.convert(20)...unit.convert(110))
            .chartXAxisLabel(unit.symbol)
            .chartYAxisLabel("%")
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .gesture(dragGesture(proxy: proxy, geometry: geometry, unit: unit))
                }
            }
            .frame(height: 240)

            HStack {
                Text("Drag the points to shape the curve.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    let last = sorted.last
                    points.append(CurvePoint(temperature: min((last?.temperature ?? 60) + 5, 110), percent: min((last?.percent ?? 50) + 10, 100)))
                } label: {
                    Label("Add Point", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.sky)
                Toggle("Values", isOn: $showsValues.animation(.snappy))
                    .toggleStyle(.button)
                    .controlSize(.small)
            }

            if showsValues {
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
            }
        }
    }

    private func dragGesture(proxy: ChartProxy, geometry: GeometryProxy, unit: TemperatureUnit) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let plot = proxy.plotFrame else { return }
                let origin = geometry[plot].origin
                let location = CGPoint(x: value.location.x - origin.x, y: value.location.y - origin.y)
                if draggingID == nil {
                    draggingID = nearestPoint(to: location, proxy: proxy, unit: unit)
                }
                guard let id = draggingID, let index = points.firstIndex(where: { $0.id == id }),
                      let x: Double = proxy.value(atX: location.x),
                      let y: Double = proxy.value(atY: location.y) else { return }
                let celsius = unit == .celsius ? x : (x - 32) * 5 / 9
                points[index].temperature = min(max(celsius, 20), 110).rounded()
                points[index].percent = (min(max(y, 0), 100) / 5).rounded() * 5
            }
            .onEnded { _ in draggingID = nil }
    }

    private func nearestPoint(to location: CGPoint, proxy: ChartProxy, unit: TemperatureUnit) -> UUID? {
        let candidates = points.compactMap { point -> (UUID, CGFloat)? in
            guard let x = proxy.position(forX: unit.convert(point.temperature)),
                  let y = proxy.position(forY: point.percent) else { return nil }
            return (point.id, hypot(x - location.x, y - location.y))
        }
        guard let nearest = candidates.min(by: { $0.1 < $1.1 }), nearest.1 < 24 else { return nil }
        return nearest.0
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
