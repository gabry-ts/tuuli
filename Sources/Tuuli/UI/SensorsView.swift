import PartitiUI
import SwiftUI
import TuuliCore

struct SensorsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(\.colorScheme) private var colorScheme
    @State private var search = ""
    @State private var hottestFirst = false

    var body: some View {
        let unit = store.settings.unit
        let ink = Ink(colorScheme)
        let sorts: [(value: Bool, title: LocalizedStringKey)] = [(false, "By name"), (true, "Hottest first")]
        TuuliPane(.sensors, subtitle: "\(monitor.sensors.count) sensors found on this Mac") {
            HStack(spacing: PUI.Space.l) {
                HStack(spacing: PUI.Space.s) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.secondary)
                    TextField("Search sensors", text: $search)
                        .textFieldStyle(.plain)
                        .font(PUI.Font.body)
                }
                .padding(.horizontal, PUI.Space.m)
                .frame(height: PUI.Control.regular)
                .background(RoundedRectangle(cornerRadius: PUI.Radius.row, style: .continuous).fill(ink.fill))
                SegmentedPill(sorts, selection: $hottestFirst, height: PUI.Control.regular)
                HStack(spacing: PUI.Space.m) {
                    Text("All sensors")
                        .font(PUI.Font.callout)
                        .foregroundStyle(ink.secondary)
                    Toggle("All sensors", isOn: store.binding(\.showAllSensors))
                        .toggleStyle(PUISwitchStyle(showsLabel: false))
                }
                .fixedSize()
            }

            if search.isEmpty {
                SettingsGroup("Summary") {
                    ForEach(monitor.availableAggregates, id: \.self) { aggregate in
                        SensorReadingRow(title: aggregate.title, key: nil, celsius: monitor.value(aggregate.sensorID), unit: unit)
                    }
                }
            }

            if store.settings.showAllSensors || !search.isEmpty {
                ForEach(SensorCategory.allCases, id: \.self) { category in
                    let sensors = filtered(category)
                    if !sensors.isEmpty {
                        SettingsGroup(Text("\(Image(systemName: category.icon)) \(category.title)")) {
                            ForEach(sensors) { sensor in
                                SensorReadingRow(title: sensor.name, key: sensor.id, celsius: monitor.value(sensor.id), unit: unit)
                            }
                        }
                    }
                }
            } else {
                Text("Turn on All sensors, or search, to see every reading grouped by category. Key names vary between Mac models.")
                    .font(PUI.Font.callout)
                    .foregroundStyle(ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, PUI.Space.xs)
            }
        }
    }

    private func filtered(_ category: SensorCategory) -> [Sensor] {
        var sensors = monitor.sensors.filter { $0.category == category }
        if !search.isEmpty {
            sensors = sensors.filter {
                $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search)
            }
        }
        if hottestFirst {
            sensors.sort { (monitor.value($0.id) ?? 0) > (monitor.value($1.id) ?? 0) }
        }
        return sensors
    }
}

private struct SensorReadingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let key: String?
    let celsius: Double?
    let unit: TemperatureUnit

    var body: some View {
        let ink = Ink(colorScheme)
        HStack(spacing: PUI.Space.l) {
            Circle()
                .fill(Heat.color(celsius))
                .frame(width: 7, height: 7)
            Text(title)
                .font(PUI.Font.body)
                .foregroundStyle(ink.primary)
                .lineLimit(1)
                .frame(minWidth: 150, alignment: .leading)
            if let key {
                Text(key)
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(ink.tertiary)
                    .frame(width: 44, alignment: .leading)
            }
            Meter(Heat.fraction(celsius), color: Heat.color(celsius), height: 4)
            Text(verbatim: unit.format(celsius))
                .font(PUI.Font.body)
                .monospacedDigit()
                .foregroundStyle(ink.secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, PUI.Space.l)
        .frame(minHeight: 34)
    }
}

extension SensorCategory {
    var icon: String {
        switch self {
        case .cpuPerformance: "cpu"
        case .cpuEfficiency: "leaf"
        case .gpu: "square.stack.3d.up"
        case .ssd: "internaldrive"
        case .battery: "battery.75percent"
        case .wireless: "wifi"
        case .ambient: "thermometer.sun"
        case .surface: "hand.raised"
        case .other: "circle.grid.3x3"
        }
    }
}
