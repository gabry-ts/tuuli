import Charts
import SwiftUI
import TuuliCore

/// The menu bar popover. Each section can be turned on or off under Menu Bar settings.
struct MenuContent: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine
    @Environment(HelperClient.self) private var helper
    let openSettings: () -> Void
    /// Applies fan changes right away instead of waiting for the next sample.
    let applyNow: () -> Void

    var body: some View {
        let popover = store.settings.popover
        VStack(alignment: .leading, spacing: 10) {
            header
            ForEach(popover.sections.filter(\.isEnabled), id: \.section) { entry in
                sectionView(entry.section, popover: popover)
            }
            footer
        }
        .padding(12)
        .frame(width: 300)
        .background(AirBackground())
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "fan.fill")
                .foregroundStyle(Theme.sky.gradient)
            Text("Tuuli")
                .font(.system(.headline, design: .rounded))
            Spacer()
            Label(monitor.isOnBattery ? "Battery" : "Power Adapter",
                  systemImage: monitor.isOnBattery ? "battery.75percent" : "bolt.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",")
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .font(.callout)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func sectionView(_ section: PopoverSection, popover: PopoverSettings) -> some View {
        let unit = store.settings.unit
        switch section {
        case .temperatures:
            if !popover.temperatureSensors.isEmpty {
                Card(padding: 12) {
                    VStack(spacing: 8) {
                        ForEach(Array(popover.temperatureSensors.enumerated()), id: \.offset) { _, sensor in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.heat(monitor.value(sensor)))
                                    .frame(width: 7, height: 7)
                                Text(monitor.name(of: sensor))
                                Spacer()
                                TemperatureText(celsius: monitor.value(sensor), unit: unit)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        case .chart:
            Card(padding: 12) {
                hero(sensor: popover.chartSensor, minutes: popover.chartMinutes)
            }
        case .fans:
            Card(padding: 12) {
                VStack(spacing: 10) {
                    if monitor.fans.isEmpty {
                        Text("No fans on this Mac").foregroundStyle(.secondary)
                    }
                    ForEach(monitor.fans) { fan in
                        HStack(spacing: 10) {
                            SpinningFan(rpm: fan.current, size: 15)
                            Text(fan.name)
                                .frame(width: 44, alignment: .leading)
                            FanBar(fan: fan)
                            Text(verbatim: fan.rpmText)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                }
            }
        case .modePicker:
            Card(padding: 12) {
                modeSection
            }
        }
    }

    private func hero(sensor: String, minutes: Int) -> some View {
        let value = monitor.value(sensor)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                TemperatureText(celsius: value, unit: store.settings.unit, compact: true)
                    .font(.system(size: 34, weight: .light, design: .rounded))
                VStack(alignment: .leading, spacing: 0) {
                    Text(Theme.mood(value))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.heat(value))
                    Text(monitor.name(of: sensor))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            sparkline(sensor: sensor, minutes: minutes)
        }
    }

    // MARK: Mode

    private var activeMode: Mode { store.settings.activeMode }

    @ViewBuilder
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(store.settings.modes) { mode in
                    ModeChip(mode: mode, isActive: mode.id == store.settings.activeModeID) {
                        store.settings.activeModeID = mode.id
                        applyNow()
                    }
                }
            }
            .disabled(!helper.isReady)

            if activeMode.kind == .manual {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .foregroundStyle(.secondary)
                    Slider(value: manualPercent, in: 0...100, step: 5) { editing in
                        if !editing { applyNow() }
                    }
                    .tint(Theme.sky)
                    Text(verbatim: "\(Int(activeMode.adapter.manualPercent))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!helper.isReady)
            }

            if !helper.isReady {
                HStack {
                    caption("Fan control needs the helper.")
                    Spacer()
                    Button("Set Up…", action: openSettings)
                        .controlSize(.small)
                }
            } else {
                caption(holdingText)
            }
        }
    }

    private var holdingText: String {
        engine.targetPercent.map { "Fans held at \(Int($0.rounded()))%" } ?? "macOS is in charge of the fans"
    }

    private var manualPercent: Binding<Double> {
        Binding(
            get: { activeMode.adapter.manualPercent },
            set: { value in
                if let index = store.settings.index(of: activeMode.id) {
                    store.settings.modes[index].adapter.manualPercent = value
                }
            }
        )
    }

    // MARK: Pieces

    private func sparkline(sensor: String, minutes: Int) -> some View {
        let start = Date().addingTimeInterval(-Double(minutes) * 60)
        let unit = store.settings.unit
        let points = monitor.history.filter { $0.date >= start }.compactMap { sample in
            sample.values[sensor].map { (sample.date, unit.convert($0)) }
        }
        let low = (points.map(\.1).min() ?? 0) - 2
        let high = (points.map(\.1).max() ?? 1) + 2
        let color = Theme.heat(monitor.value(sensor))
        return Chart(points, id: \.0) { point in
            AreaMark(x: .value("Time", point.0), yStart: .value("Low", low), yEnd: .value("Temperature", point.1))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(colors: [color.opacity(0.3), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Time", point.0), y: .value("Temperature", point.1))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: low...max(high, low + 1))
        .frame(height: 48)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
