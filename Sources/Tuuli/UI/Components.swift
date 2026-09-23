import SwiftUI
import TuuliCore

/// Picks an aggregate or an individual sensor, grouped by category.
struct SensorPicker: View {
    @Environment(Monitor.self) private var monitor
    let title: String
    @Binding var selection: String?
    var allowsNone = false

    init(title: String, selection: Binding<String>) {
        self.title = title
        _selection = Binding(get: { selection.wrappedValue }, set: { if let id = $0 { selection.wrappedValue = id } })
    }

    init(title: String, optionalSelection: Binding<String?>) {
        self.title = title
        _selection = optionalSelection
        allowsNone = true
    }

    var body: some View {
        Picker(title, selection: $selection) {
            if allowsNone {
                Text("None").tag(String?.none)
            }
            Section("Summary") {
                ForEach(Aggregate.allCases, id: \.self) { aggregate in
                    Text(aggregate.title).tag(Optional(aggregate.sensorID))
                }
            }
            ForEach(SensorCategory.allCases, id: \.self) { category in
                let sensors = monitor.sensors.filter { $0.category == category }
                if !sensors.isEmpty {
                    Section(category.title) {
                        ForEach(sensors) { sensor in
                            Text("\(sensor.name) (\(sensor.id))").tag(Optional(sensor.id))
                        }
                    }
                }
            }
        }
    }
}

/// Temperature stepper with a unit-aware label; values are always stored in °C.
struct TemperatureField: View {
    let title: String
    @Binding var celsius: Double
    let unit: TemperatureUnit
    var range: ClosedRange<Double> = 30...110

    var body: some View {
        Stepper(value: $celsius, in: range, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text(unit.format(celsius))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PercentSlider: View {
    let title: String
    @Binding var percent: Double

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $percent, in: 0...100, step: 5)
                Text("\(Int(percent))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

extension SettingsStore {
    func binding<T>(_ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { self.settings[keyPath: keyPath] = $0 }
        )
    }
}
