import SwiftUI

struct SettingsView: View {
    @State private var selection: Pane?

    enum Pane: String, CaseIterable, Hashable {
        case overview
        case sensors
        case fans
        case alerts
        case menuBar
        case logging
        case general

        var title: String {
            switch self {
            case .overview: "Overview"
            case .sensors: "Sensors"
            case .fans: "Fan Control"
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
            case .fans: "fan"
            case .alerts: "bell"
            case .menuBar: "menubar.rectangle"
            case .logging: "doc.text"
            case .general: "gearshape"
            }
        }
    }

    init(initialSelection: Pane = .overview) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, id: \.self, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail
                .navigationTitle(selection?.title ?? "Tuuli")
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview: OverviewView()
        case .sensors: SensorsView()
        case .fans: FansView()
        case .alerts: AlertsView()
        case .menuBar: MenuBarSettingsView()
        case .logging: LoggingView()
        case .general: GeneralView()
        case nil: ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
        }
    }
}
