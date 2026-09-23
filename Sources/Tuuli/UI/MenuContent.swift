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
        VStack(alignment: .leading, spacing: 12) {
            ForEach(popover.sections.filter(\.isEnabled), id: \.section) { entry in
                sectionView(entry.section, popover: popover)
            }
            HStack {
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit Tuuli") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    @ViewBuilder
    private func sectionView(_ section: PopoverSection, popover: PopoverSettings) -> some View {
        switch section {
        case .temperatures:
            if !popover.temperatureSensors.isEmpty {
                self.section("Temperatures") {
                    ForEach(Array(popover.temperatureSensors.enumerated()), id: \.offset) { _, sensor in
                        row(monitor.name(of: sensor), store.settings.unit.format(monitor.value(sensor)))
                    }
                }
                Divider()
            }
        case .chart:
            self.section(monitor.name(of: popover.chartSensor)) {
                sparkline(sensor: popover.chartSensor, minutes: popover.chartMinutes)
            }
            Divider()
        case .fans:
            self.section("Fans") {
                if monitor.fans.isEmpty {
                    Text("No fans detected").foregroundStyle(.secondary)
                }
                ForEach(monitor.fans) { fan in
                    row(fan.name, fan.current > 0 ? "\(Int(fan.current.rounded())) rpm" : "Off")
                }
            }
            Divider()
        case .modePicker:
            modeSection
            Divider()
        }
    }

    // MARK: Mode

    private var activeMode: Mode { store.settings.activeMode }

    @ViewBuilder
    private var modeSection: some View {
        @Bindable var store = store
        section("Mode") {
            Picker("Mode", selection: $store.settings.activeModeID) {
                ForEach(store.settings.modes) { mode in
                    Label(mode.name, systemImage: mode.kind.icon).tag(mode.id)
                }
            }
            .labelsHidden()
            .disabled(!helper.isReady)
            .onChange(of: store.settings.activeModeID) { applyNow() }

            if activeMode.kind == .manual {
                HStack {
                    Image(systemName: "fan")
                        .foregroundStyle(.secondary)
                    Slider(value: manualPercent, in: 0...100, step: 5) { editing in
                        if !editing { applyNow() }
                    }
                    Text("\(Int(activeMode.adapter.manualPercent))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!helper.isReady)
            }

            if !helper.isReady {
                caption("Install the helper in Settings to control fans.")
            } else {
                caption("\(monitor.isOnBattery ? "Battery" : "Power Adapter")\(holdingText)")
            }
        }
    }

    private var holdingText: String {
        engine.targetPercent.map { " · holding \(Int($0.rounded()))%" } ?? " · system controls the fans"
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
        return Chart(points, id: \.0) { point in
            AreaMark(x: .value("Time", point.0), y: .value("Temperature", point.1))
                .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Time", point.0), y: .value("Temperature", point.1))
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
        }
        .frame(height: 70)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
