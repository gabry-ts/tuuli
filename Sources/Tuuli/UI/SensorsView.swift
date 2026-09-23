import SwiftUI
import TuuliCore

struct SensorsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let unit = store.settings.unit
        Form {
            Section {
                Toggle("Show all sensors", isOn: store.binding(\.showAllSensors))
            } footer: {
                Text("Sensors are discovered from the SMC and grouped by key prefix. Key names vary between Mac models.")
                    .foregroundStyle(.secondary)
            }

            Section("Summary") {
                ForEach(monitor.availableAggregates, id: \.self) { aggregate in
                    reading(aggregate.title, unit.format(monitor.value(aggregate.sensorID)))
                }
            }

            if store.settings.showAllSensors {
                ForEach(SensorCategory.allCases, id: \.self) { category in
                    let sensors = monitor.sensors.filter { $0.category == category }
                    if !sensors.isEmpty {
                        Section(category.title) {
                            ForEach(sensors) { sensor in
                                reading(sensor.name, unit.format(monitor.value(sensor.id)), key: sensor.id)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func reading(_ title: String, _ value: String, key: String? = nil) -> some View {
        HStack {
            Text(title)
            if let key {
                Text(key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
