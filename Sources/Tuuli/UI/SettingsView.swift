import SwiftUI
import TuuliCore

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: SidebarItem?
    @State private var renamingModeID: UUID?
    @State private var renameText = ""

    enum Pane: String, CaseIterable, Hashable {
        case overview
        case sensors
        case alerts
        case menuBar
        case logging
        case general

        var title: String {
            switch self {
            case .overview: "Overview"
            case .sensors: "Sensors"
            case .alerts: "Alerts"
            case .menuBar: "Menu Bar"
            case .logging: "Logging"
            case .general: "General"
            }
        }

        var icon: String {
            switch self {
            case .overview: "chart.xyaxis.line"
            case .sensors: "thermometer.medium"
            case .alerts: "bell"
            case .menuBar: "menubar.rectangle"
            case .logging: "doc.text"
            case .general: "gearshape"
            }
        }
    }

    enum SidebarItem: Hashable {
        case pane(Pane)
        case mode(UUID)
    }

    init(initialSelection: SidebarItem = .pane(.overview)) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    paneRow(.overview)
                    paneRow(.sensors)
                }
                Section("Modes") {
                    ForEach(store.settings.modes) { mode in
                        modeRow(mode)
                            .tag(SidebarItem.mode(mode.id))
                    }
                    Button {
                        selection = .mode(store.addMode())
                    } label: {
                        Label("Add Mode", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Section {
                    paneRow(.alerts)
                    paneRow(.menuBar)
                    paneRow(.logging)
                    paneRow(.general)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            detail
        }
        .frame(minWidth: 920, minHeight: 560)
        .alert("Rename Mode", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renamingModeID {
                    store.renameMode(renamingModeID, to: renameText)
                }
            }
        }
    }

    private func paneRow(_ pane: Pane) -> some View {
        Label(pane.title, systemImage: pane.icon)
            .tag(SidebarItem.pane(pane))
    }

    private func modeRow(_ mode: Mode) -> some View {
        HStack {
            Label(mode.name, systemImage: mode.kind.icon)
            Spacer()
            if mode.id == store.settings.activeModeID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                    .help("Active mode")
            }
        }
        .contextMenu {
            Button("Use This Mode") { store.settings.activeModeID = mode.id }
                .disabled(mode.id == store.settings.activeModeID)
            Divider()
            Button("Rename…") {
                renameText = mode.name
                renamingModeID = mode.id
            }
            Button("Duplicate") {
                if let id = store.duplicateMode(mode.id) {
                    selection = .mode(id)
                }
            }
            if !mode.isBuiltIn {
                Divider()
                Button("Delete", role: .destructive) {
                    if selection == .mode(mode.id) {
                        selection = .pane(.overview)
                    }
                    store.deleteMode(mode.id)
                }
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renamingModeID != nil },
            set: { if !$0 { renamingModeID = nil } }
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .pane(let pane):
            paneView(pane)
                .navigationTitle(pane.title)
        case .mode(let id):
            if let mode = store.settings.modes.first(where: { $0.id == id }) {
                ModeEditorView(modeID: id)
                    .id(id)
                    .navigationTitle(mode.name)
            } else {
                ContentUnavailableView("No Mode Selected", systemImage: "fan")
            }
        case nil:
            ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
        }
    }

    @ViewBuilder
    private func paneView(_ pane: Pane) -> some View {
        switch pane {
        case .overview: OverviewView()
        case .sensors: SensorsView()
        case .alerts: AlertsView()
        case .menuBar: MenuBarSettingsView()
        case .logging: LoggingView()
        case .general: GeneralView()
        }
    }
}

extension FanMode {
    var icon: String {
        switch self {
        case .system: "apple.logo"
        case .boost: "arrow.up.circle"
        case .curve: "point.topleft.down.to.point.bottomright.curvepath"
        case .manual: "slider.horizontal.3"
        }
    }
}
