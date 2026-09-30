import PartitiUI
import SwiftUI
import TuuliCore

/// The settings window: Partiti UI's floating sidebar with the fixed panes, the modes,
/// and About.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var selection: Page

    enum Pane: String, CaseIterable, Hashable {
        case overview
        case sensors
        case alerts
        case menuBar
        case logging
        case general
        case about

        var title: String {
            switch self {
            case .overview: "Overview"
            case .sensors: "Sensors"
            case .alerts: "Alerts"
            case .menuBar: "Menu Bar"
            case .logging: "Logging"
            case .general: "General"
            case .about: "About"
            }
        }

        var icon: String {
            switch self {
            case .overview: "chart.xyaxis.line"
            case .sensors: "thermometer.medium"
            case .alerts: "bell.fill"
            case .menuBar: "menubar.rectangle"
            case .logging: "doc.text.fill"
            case .general: "gearshape.fill"
            case .about: "info"
            }
        }

        /// The tile color behind the icon, as in System Settings.
        var tint: Color {
            switch self {
            case .overview: AppAccent.tuuli.color
            case .sensors: .orange
            case .alerts: .red
            case .menuBar: .blue
            case .logging: .brown
            case .general: .gray
            case .about: .teal
            }
        }
    }

    /// What the window shows: a fixed pane or one of the modes.
    enum Page: Hashable {
        case pane(Pane)
        case mode(UUID)

        /// The sidebar selects by a string id.
        var id: String {
            switch self {
            case .pane(let pane): pane.rawValue
            case .mode(let id): "mode-\(id.uuidString)"
            }
        }
    }

    /// The sidebar entry that adds a mode rather than showing a page.
    private static let addModeID = "add-mode"

    init(initialSelection: Page = .pane(.overview)) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        SettingsWindow(sections: sections, selection: sidebarSelection) {
            page
        }
        .frame(minWidth: PUI.Window.dashboardMin.width, minHeight: PUI.Window.dashboardMin.height)
        .puiAccent(.tuuli)
    }

    private var sections: [SidebarSection] {
        let modes = store.settings.modes.map { mode in
            SidebarItem(Text(verbatim: mode.name), id: Page.mode(mode.id).id, symbol: mode.kind.icon, style: .plain,
                        checked: mode.id == store.settings.activeModeID)
        }
        return [
            SidebarSection(nil, [item(.overview), item(.sensors)]),
            SidebarSection("Modes", modes + [SidebarItem("Add Mode", id: Self.addModeID, symbol: "plus", style: .plain)]),
            SidebarSection(nil, [item(.alerts), item(.menuBar), item(.logging), item(.general), item(.about)]),
        ]
    }

    private func item(_ pane: Pane) -> SidebarItem {
        SidebarItem(Text(verbatim: pane.title), id: pane.rawValue, symbol: pane.icon, style: .tile(pane.tint))
    }

    private var sidebarSelection: Binding<String> {
        Binding(
            get: { selection.id },
            set: { id in
                if id == Self.addModeID {
                    selection = .mode(store.addMode())
                } else if let pane = Pane(rawValue: id) {
                    selection = .pane(pane)
                } else if let mode = store.settings.modes.first(where: { Page.mode($0.id).id == id }) {
                    selection = .mode(mode.id)
                }
            }
        )
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .pane(let pane):
            paneView(pane)
        case .mode(let id):
            if store.settings.modes.contains(where: { $0.id == id }) {
                ModeEditorView(modeID: id) { next in selection = next }
                    .id(id)
            } else {
                paneView(.overview)
            }
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
        case .about: AboutView()
        }
    }
}

/// A scrolling settings pane opening with Partiti UI's header.
struct TuuliPane<Trailing: View, Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            SettingsPane {
                PaneHeader(title, subtitle: subtitle, symbol: symbol, color: color) { trailing }
            } content: {
                content
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

extension TuuliPane where Trailing == EmptyView {
    init(_ pane: SettingsView.Pane, subtitle: String, @ViewBuilder content: () -> Content) {
        self.init(title: pane.title, subtitle: subtitle, symbol: pane.icon, color: pane.tint,
                  trailing: { EmptyView() }, content: content)
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
