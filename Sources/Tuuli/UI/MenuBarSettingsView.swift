import PartitiUI
import SwiftUI
import TuuliCore
import UniformTypeIdentifiers

/// Menu bar settings: a draggable status item strip, draggable popover sections, and a
/// live preview of both on the right.
struct MenuBarSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var draggingItem: Int?
    @State private var draggingSection: Int?
    @State private var draggingSensor: Int?
    @State private var editingItem: Int?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            TuuliPane(.menuBar, subtitle: "What sits in the menu bar, and what opens under it.") {
                SettingsGroup("Status Item", footer: "Drag to reorder. Click a reading to change or remove it.") {
                    statusStrip
                        .padding(PUI.Space.l)
                }

                SettingsGroup("Popover", footer: "Drag to reorder. Switch off what you don't need.") {
                    popoverSections
                }
            }

            MenuBarPreview()
                .frame(width: PUI.Popover.regular + 2 * PUI.Space.xl)
        }
    }

    // MARK: Status item

    private var statusStrip: some View {
        let items = store.settings.menuBar.items
        return HStack(spacing: 6) {
            Spacer(minLength: 0)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                StatusChip(item: item, isDragging: draggingItem == index)
                    .onTapGesture { editingItem = index }
                    .popover(isPresented: editingBinding(index), arrowEdge: .bottom) {
                        chipEditor(index: index, item: item)
                    }
                    .reorderable(index: index, items: itemsBinding, dragging: $draggingItem)
            }
            addItemMenu
        }
        .padding(.horizontal, PUI.Space.m + 2)
        .padding(.vertical, PUI.Space.s)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(RoundedRectangle(cornerRadius: PUI.Radius.group, style: .continuous).fill(Ink(colorScheme).fill))
        .animation(.snappy, value: items)
    }

    private var addItemMenu: some View {
        Menu {
            SensorMenu(title: "Temperature") { sensor in
                store.settings.menuBar.items.append(.temperature(sensor))
            }
            Button("Fan Speed") { store.settings.menuBar.items.append(.fanSpeed) }
                .disabled(store.settings.menuBar.items.contains(.fanSpeed))
            Button("Icon") { store.settings.menuBar.items.append(.icon) }
                .disabled(store.settings.menuBar.items.contains(.icon))
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add an item")
    }

    @ViewBuilder
    private func chipEditor(index: Int, item: StatusElement) -> some View {
        VStack(alignment: .leading, spacing: PUI.Space.l) {
            if case .temperature(let sensor) = item {
                HStack(spacing: PUI.Space.m) {
                    Text("Sensor")
                        .font(PUI.Font.body)
                    SensorField(title: "Sensor", selection: Binding(
                        get: { sensor },
                        set: { store.settings.menuBar.items[index] = .temperature($0) }
                    ))
                }
            } else {
                Text(item == .icon ? "Fan icon" : "Fastest fan speed")
                    .font(PUI.Font.body)
                    .foregroundStyle(.secondary)
            }
            Button("Remove", role: .destructive) {
                editingItem = nil
                store.settings.menuBar.items.remove(at: index)
            }
            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
        }
        .padding(PUI.Space.l)
        .frame(minWidth: 240, alignment: .leading)
    }

    private func editingBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { editingItem == index },
            set: { if !$0 { editingItem = nil } }
        )
    }

    private var itemsBinding: Binding<[StatusElement]> {
        Binding(
            get: { store.settings.menuBar.items },
            set: { store.settings.menuBar.items = $0 }
        )
    }

    // MARK: Popover sections

    private var popoverSections: some View {
        let sections = store.settings.popover.sections
        return VStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.section) { index, entry in
                if index > 0 { Hairline().padding(.horizontal, PUI.Space.l) }
                sectionCard(index: index, entry: entry)
                    .reorderable(index: index, items: sectionsBinding, dragging: $draggingSection)
            }
        }
        .animation(.snappy, value: sections)
    }

    private func sectionCard(index: Int, entry: PopoverEntry) -> some View {
        @Bindable var store = store
        let ink = Ink(colorScheme)
        return VStack(alignment: .leading, spacing: PUI.Space.m) {
            HStack(spacing: PUI.Space.m + 2) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(ink.tertiary)
                Image(systemName: entry.section.icon)
                    .foregroundStyle(entry.isEnabled ? AppAccent.tuuli.legible(colorScheme) : ink.secondary)
                    .frame(width: 20)
                Text(entry.section.title)
                    .font(PUI.Font.body)
                    .foregroundStyle(entry.isEnabled ? ink.primary : ink.secondary)
                Spacer()
                Toggle(entry.section.title, isOn: $store.settings.popover.sections[index].isEnabled)
                    .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
            }
            if entry.isEnabled {
                sectionOptions(entry.section)
                    .padding(.leading, 50)
            }
        }
        .padding(PUI.Space.l)
        .opacity(draggingSection == index ? 0.5 : 1)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func sectionOptions(_ section: PopoverSection) -> some View {
        @Bindable var store = store
        switch section {
        case .temperatures:
            sensorChips
        case .chart:
            let windows: [(value: Int, title: LocalizedStringKey)] = [(5, "5 min"), (15, "15 min"), (60, "60 min")]
            HStack(spacing: PUI.Space.m) {
                SensorField(title: "Sensor", selection: $store.settings.popover.chartSensor)
                SegmentedPill(windows, selection: $store.settings.popover.chartMinutes)
            }
        case .fans, .modePicker:
            EmptyView()
        }
    }

    private var sensorChips: some View {
        let sensors = store.settings.popover.temperatureSensors
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(sensors.enumerated()), id: \.offset) { index, sensor in
                SensorRow(sensor: sensor, isDragging: draggingSensor == index) {
                    store.settings.popover.temperatureSensors.remove(at: index)
                }
                .reorderable(index: index, items: sensorsBinding, dragging: $draggingSensor)
            }
            SensorMenu(title: "Add Temperature", systemImage: "plus") { sensor in
                store.settings.popover.temperatureSensors.append(sensor)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .padding(.top, 2)
        }
    }

    private var sectionsBinding: Binding<[PopoverEntry]> {
        Binding(
            get: { store.settings.popover.sections },
            set: { store.settings.popover.sections = $0 }
        )
    }

    private var sensorsBinding: Binding<[String]> {
        Binding(
            get: { store.settings.popover.temperatureSensors },
            set: { store.settings.popover.temperatureSensors = $0 }
        )
    }
}

// MARK: - Pieces

/// One reading in the status item strip, drawn like the real menu bar.
private struct StatusChip: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    let item: StatusElement
    let isDragging: Bool
    @State private var isHovering = false

    var body: some View {
        content
            .font(PUI.Font.menuBar)
            .padding(.horizontal, PUI.Space.m)
            .padding(.vertical, 3)
            .puiHoverHighlight(isHovering, radius: 5)
            .opacity(isDragging ? 0.4 : 1)
            .contentShape(.rect)
            .onHover { isHovering = $0 }
            .help(help)
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .icon:
            Image(systemName: "fan.fill")
        case .temperature(let sensor):
            Text(verbatim: store.settings.unit.short(monitor.value(sensor)))
        case .fanSpeed:
            Text(verbatim: monitor.fans.map(\.current).max().map { "\(Int($0.rounded())) rpm" } ?? "– rpm")
        }
    }

    private var help: String {
        switch item {
        case .icon: "Icon"
        case .temperature(let sensor): monitor.name(of: sensor)
        case .fanSpeed: "Fan speed"
        }
    }
}

/// A sensor in the popover's temperature list, with a remove button on hover.
private struct SensorRow: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    let sensor: String
    let isDragging: Bool
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: PUI.Space.m) {
            Image(systemName: "line.3.horizontal")
                .font(PUI.Font.caption)
                .foregroundStyle(.tertiary)
            Text(monitor.name(of: sensor))
                .font(PUI.Font.body)
            Spacer()
            Text(store.settings.unit.format(monitor.value(sensor)))
                .font(PUI.Font.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isHovering ? 1 : 0)
            .help("Remove")
        }
        .padding(.horizontal, PUI.Space.m)
        .padding(.vertical, 5)
        .puiHoverHighlight(isHovering, radius: 6)
        .opacity(isDragging ? 0.4 : 1)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
    }
}

/// A menu listing summary values and every sensor by category.
struct SensorMenu: View {
    @Environment(Monitor.self) private var monitor
    let title: String
    var systemImage: String?
    let pick: (String) -> Void

    var body: some View {
        Menu {
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
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
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

// MARK: - Drag to reorder

private struct ReorderDropDelegate<Item>: DropDelegate {
    let index: Int
    @Binding var items: [Item]
    @Binding var dragging: Int?

    func dropEntered(info: DropInfo) {
        guard let from = dragging, from != index, items.indices.contains(from) else { return }
        items.move(fromOffsets: [from], toOffset: index > from ? index + 1 : index)
        dragging = index
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

extension View {
    /// Live drag-and-drop reordering within one list. Each list needs its own `dragging`
    /// state, so drags never leak between lists.
    fileprivate func reorderable<Item>(index: Int, items: Binding<[Item]>, dragging: Binding<Int?>) -> some View {
        onDrag {
            dragging.wrappedValue = index
            return NSItemProvider(object: String(index) as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(index: index, items: items, dragging: dragging))
    }
}
