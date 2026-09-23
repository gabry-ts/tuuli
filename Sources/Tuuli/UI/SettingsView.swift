import SwiftUI
import TuuliCore

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: SidebarItem?
    @State private var renamingProfileID: UUID?
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
        case profile(UUID)
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
                Section("Profiles") {
                    ForEach(store.settings.profiles) { profile in
                        profileRow(profile)
                            .tag(SidebarItem.profile(profile.id))
                    }
                    Button {
                        selection = .profile(store.addProfile())
                    } label: {
                        Label("Add Profile", systemImage: "plus")
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
        .frame(minWidth: 760, minHeight: 540)
        .alert("Rename Profile", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renamingProfileID {
                    store.renameProfile(renamingProfileID, to: renameText)
                }
            }
        }
    }

    private func paneRow(_ pane: Pane) -> some View {
        Label(pane.title, systemImage: pane.icon)
            .tag(SidebarItem.pane(pane))
    }

    private func profileRow(_ profile: FanProfile) -> some View {
        HStack {
            Label(profile.name, systemImage: profile.config.mode.icon)
            Spacer()
            if profile.id == store.settings.adapterProfileID {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.secondary)
                    .help("Used on power adapter")
            }
            if PowerSource.hasBattery, profile.id == store.settings.batteryProfileID {
                Image(systemName: "battery.75percent")
                    .foregroundStyle(.secondary)
                    .help("Used on battery")
            }
        }
        .contextMenu {
            Button("Rename…") {
                renameText = profile.name
                renamingProfileID = profile.id
            }
            Button("Duplicate") {
                if let id = store.duplicateProfile(profile.id) {
                    selection = .profile(id)
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                if selection == .profile(profile.id) {
                    selection = .pane(.overview)
                }
                store.deleteProfile(profile.id)
            }
            .disabled(store.settings.profiles.count <= 1)
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renamingProfileID != nil },
            set: { if !$0 { renamingProfileID = nil } }
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .pane(let pane):
            paneView(pane)
                .navigationTitle(pane.title)
        case .profile(let id):
            if let profile = store.settings.profiles.first(where: { $0.id == id }) {
                ProfileEditorView(profileID: id)
                    .id(id)
                    .navigationTitle(profile.name)
            } else {
                ContentUnavailableView("No Profile Selected", systemImage: "fan")
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
