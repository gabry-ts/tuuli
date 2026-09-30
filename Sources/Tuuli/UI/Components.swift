import PartitiUI
import SwiftUI
import TuuliCore

/// Picks an aggregate or an individual sensor, grouped by category, from a pop-up field
/// showing the sensor's name.
struct SensorField: View {
    @Environment(Monitor.self) private var monitor
    let title: String
    @Binding var selection: String

    var body: some View {
        PopUpMenu(monitor.name(of: selection), symbol: "thermometer.medium") {
            Picker(title, selection: $selection) {
                Section("Summary") {
                    ForEach(Aggregate.allCases, id: \.self) { aggregate in
                        Text(aggregate.title).tag(aggregate.sensorID)
                    }
                }
                ForEach(SensorCategory.allCases, id: \.self) { category in
                    let sensors = monitor.sensors.filter { $0.category == category }
                    if !sensors.isEmpty {
                        Section(category.title) {
                            ForEach(sensors) { sensor in
                                Text(verbatim: "\(sensor.name) (\(sensor.id))").tag(sensor.id)
                            }
                        }
                    }
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .accessibilityLabel(title)
    }
}

/// A value with a stepper beside it, for settings rows. Partiti UI has no stepper.
struct StepperValue: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var color: Color?

    init(_ text: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1, color: Color? = nil) {
        self.text = text
        self._value = value
        self.range = range
        self.step = step
        self.color = color
    }

    var body: some View {
        HStack(spacing: PUI.Space.s) {
            Text(verbatim: text)
                .font(PUI.Font.callout)
                .monospacedDigit()
                .foregroundStyle(color ?? Ink(colorScheme).primary)
            Stepper(text, value: $value, in: range, step: step)
                .labelsHidden()
        }
        .fixedSize()
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
