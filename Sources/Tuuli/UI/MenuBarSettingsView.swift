import PartitiUI
import SwiftUI
import TuuliCore

/// Menu bar settings: the status item's pieces and the popover's sections, in lists to
/// switch on and drag into order, with a live preview of both on the right.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    /// The lists as the user left them, once touched. The settings only keep what is
    /// shown, so the rows that are switched off live here while the pane is open.
    @State private var statusRows: [Listed<StatusElement>]?
    @State private var sensorRows: [Listed<String>]?

    var body: some View {
        @Bindable var store = store
        HStack(alignment: .top, spacing: 0) {
            TuuliPane(.menuBar, subtitle: "What sits in the menu bar, and what opens under it.") {
                SettingsGroup("Status Item",
                              footer: "Drag to reorder. Switch off what you don't need: with everything off, the icon stays.") {
                    ReorderableRows(status, isOn: \.isOn) { row in
                        statusLabel(row)
                    }
                    SettingsRow("Add a temperature") {
                        IconMenu("plus") {
                            SensorMenuItems(monitor: monitor) { add(.temperature($0), to: status) }
                        }
                        .help("Add a temperature")
                    }
                }

                ReorderableGroup("Popover", footer: "Drag to reorder. Switch off what you don't need.",
                                 items: $store.settings.popover.sections, isOn: \.isEnabled) { entry in
                    ReorderableLabel(entry.section.title, symbol: entry.section.icon)
                }

                if isShown(.temperatures) {
                    SettingsGroup("Popover Temperatures", footer: "Drag to reorder. Switch off a sensor to leave it out.") {
                        ReorderableRows(sensors, isOn: \.isOn) { row in
                            sensorLabel(row.element)
                        }
                        SettingsRow("Add a temperature") {
                            IconMenu("plus") {
                                SensorMenuItems(monitor: monitor) { add($0, to: sensors) }
                            }
                            .help("Add a temperature")
                        }
                    }
                }

                if isShown(.chart) {
                    let windows: [(value: Int, title: LocalizedStringKey)] = [(5, "5 min"), (15, "15 min"), (60, "60 min")]
                    SettingsGroup("Popover Chart") {
                        SettingsRow("Sensor") {
                            SensorField(title: "Sensor", selection: $store.settings.popover.chartSensor)
                        }
                        SettingsRow("Time window") {
                            SegmentedPill(windows, selection: $store.settings.popover.chartMinutes, height: PUI.Control.regular)
                        }
                    }
                }
            }

            MenuBarPreview()
                .frame(width: PUI.Popover.regular + 2 * PUI.Space.xl)
        }
    }

    private func isShown(_ section: PopoverSection) -> Bool {
        store.settings.popover.sections.contains { $0.section == section && $0.isEnabled }
    }

    // MARK: Status item

    /// The readings that are shown, then the icon and the fan speed if they are off.
    private var status: Binding<[Listed<StatusElement>]> {
        Binding(
            get: { statusRows ?? Listed.rows(shown: store.settings.menuBar.items, others: [.icon, .fanSpeed]) },
            set: { rows in
                statusRows = rows
                store.settings.menuBar.items = rows.filter(\.isOn).map(\.element)
            })
    }

    @ViewBuilder
    private func statusLabel(_ row: Listed<StatusElement>) -> some View {
        switch row.element {
        case .icon:
            ReorderableLabel("Icon", symbol: "fan.fill")
        case .fanSpeed:
            ReorderableLabel("Fan speed", subtitle: "The fastest fan", symbol: "wind")
        case .temperature(let sensor):
            HStack(spacing: PUI.Space.m) {
                ReorderableLabel("Temperature", symbol: "thermometer.medium")
                Spacer(minLength: PUI.Space.m)
                SensorField(title: "Sensor", selection: Binding(
                    get: { sensor },
                    set: { replace(row, with: .temperature($0)) }))
                    // Rows are also drawn as drag previews, outside the window's environment.
                    .environment(monitor)
            }
        }
    }

    /// Changes the sensor of a temperature in place, unless that reading is already listed.
    private func replace(_ row: Listed<StatusElement>, with element: StatusElement) {
        var rows = status.wrappedValue
        guard !rows.contains(where: { $0.element == element }),
              let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[index].element = element
        status.wrappedValue = rows
    }

    // MARK: Popover temperatures

    private var sensors: Binding<[Listed<String>]> {
        Binding(
            get: { sensorRows ?? Listed.rows(shown: store.settings.popover.temperatureSensors) },
            set: { rows in
                sensorRows = rows
                store.settings.popover.temperatureSensors = rows.filter(\.isOn).map(\.element)
            })
    }

    private func sensorLabel(_ sensor: String) -> some View {
        HStack(spacing: PUI.Space.m) {
            ReorderableLabel(monitor.name(of: sensor))
            Spacer(minLength: PUI.Space.m)
            ValueText(store.settings.unit.format(monitor.value(sensor)))
        }
    }

    /// Adds `element` at the end of `list`, or switches it back on if it is already there.
    private func add<Element: Hashable>(_ element: Element, to list: Binding<[Listed<Element>]>) {
        var rows = list.wrappedValue
        if let index = rows.firstIndex(where: { $0.element == element }) {
            rows[index].isOn = true
        } else {
            rows.append(Listed(element: element, isOn: true))
        }
        list.wrappedValue = rows
    }
}

// MARK: - Pieces

/// One row of a list whose settings only keep what is shown.
private struct Listed<Element: Hashable>: Identifiable {
    var element: Element
    var isOn: Bool

    var id: Element { element }

    /// The saved elements, switched on, then the `others` that aren't among them, off.
    static func rows(shown: [Element], others: [Element] = []) -> [Listed] {
        let on = shown.map { Listed(element: $0, isOn: true) }
        return Reorder.normalized(on, known: on + others.map { Listed(element: $0, isOn: false) }, by: \.element)
    }
}

/// Summary values and every sensor by category, as the items of a menu.
private struct SensorMenuItems: View {
    let monitor: Monitor
    let pick: (String) -> Void

    var body: some View {
        Section("Summary") {
            ForEach(Aggregate.allCases, id: \.self) { aggregate in
                Button(aggregate.title) { pick(aggregate.sensorID) }
            }
        }
        Section("Sensors") {
            ForEach(SensorCategory.allCases, id: \.self) { category in
                let sensors = monitor.sensors.filter { $0.category == category }
                if !sensors.isEmpty {
                    Menu(category.title) {
                        ForEach(sensors) { sensor in
                            Button("\(sensor.name) (\(sensor.id))") { pick(sensor.id) }
                        }
                    }
                }
            }
        }
    }
}

/// The status item and popover as they look right now, not interactive.
private struct MenuBarPreview: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = Ink(colorScheme)
        VStack(alignment: .trailing, spacing: PUI.Space.s) {
            SectionHeader("Live Preview")
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Spacer()
                MenuBarLabel(store: store, monitor: monitor)
                    .padding(.horizontal, PUI.Space.s + 1)
                    .frame(height: PUI.Control.small)
                    .background(Capsule().fill(ink.strongFill))
            }
            .padding(.horizontal, PUI.Space.m)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: PUI.Radius.group, style: .continuous).fill(ink.fill))
            MenuContent(openSettings: {}, applyNow: {})
                .background(.regularMaterial)
                .clipShape(.rect(cornerRadius: PUI.Radius.popover))
                .overlay(RoundedRectangle(cornerRadius: PUI.Radius.popover).strokeBorder(ink.hairline))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, PUI.Space.xl)
        .padding(.top, 88)
    }
}

extension PopoverSection {
    var icon: String {
        switch self {
        case .temperatures: "thermometer.medium"
        case .chart: "chart.xyaxis.line"
        case .fans: "fan"
        case .modePicker: "switch.2"
        }
    }
}
