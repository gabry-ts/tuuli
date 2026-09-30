import PartitiUI
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

/// Picks an aggregate or an individual sensor, grouped by category, from a pop-up field
/// showing the sensor's name.
struct SensorField: View {
    @Environment(Monitor.self) private var monitor
    let title: String
    @Binding var selection: String

    var body: some View {
        Menu {
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
        } label: {
            PopUpField(monitor.name(of: selection), symbol: "thermometer.medium")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
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

    init(_ text: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1) {
        self.text = text
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        HStack(spacing: PUI.Space.s) {
            Text(verbatim: text)
                .font(PUI.Font.callout)
                .monospacedDigit()
                .foregroundStyle(Ink(colorScheme).primary)
            Stepper(text, value: $value, in: range, step: step)
                .labelsHidden()
        }
        .fixedSize()
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
