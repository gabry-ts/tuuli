import SwiftUI
import TuuliCore

struct SensorsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @State private var search = ""
    @State private var hottestFirst = false

    var body: some View {
        let unit = store.settings.unit
        AirPage(title: "Sensors", subtitle: "\(monitor.sensors.count) sensors found on this Mac") {
            Card(padding: 12) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search sensors", text: $search)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.primary.opacity(0.05), in: .rect(cornerRadius: 8))
                    Picker("Sort", selection: $hottestFirst) {
                        Text("By name").tag(false)
                        Text("Hottest first").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Toggle("All sensors", isOn: store.binding(\.showAllSensors))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .fixedSize()
                }
            }

            if search.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        CardTitle(title: "Summary", systemImage: "sparkles")
                        ForEach(monitor.availableAggregates, id: \.self) { aggregate in
                            SensorReadingRow(title: aggregate.title, key: nil, celsius: monitor.value(aggregate.sensorID), unit: unit)
                        }
                    }
                }
            }

            if store.settings.showAllSensors || !search.isEmpty {
                ForEach(SensorCategory.allCases, id: \.self) { category in
                    let sensors = filtered(category)
                    if !sensors.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                CardTitle(title: category.title, systemImage: category.icon)
                                ForEach(sensors) { sensor in
                                    SensorReadingRow(title: sensor.name, key: sensor.id, celsius: monitor.value(sensor.id), unit: unit)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Turn on All sensors, or search, to see every reading grouped by category. Key names vary between Mac models.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
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
    let title: String
    let key: String?
    let celsius: Double?
    let unit: TemperatureUnit

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.heat(celsius))
                .frame(width: 7, height: 7)
            Text(title)
                .frame(minWidth: 150, alignment: .leading)
            if let key {
                Text(key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, alignment: .leading)
            }
            HeatBar(celsius: celsius)
            TemperatureText(celsius: celsius, unit: unit)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
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
