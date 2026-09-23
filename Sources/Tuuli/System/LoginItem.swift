import ServiceManagement

/// Thin wrapper over SMAppService for the "launch at login" toggle.
@MainActor
enum LoginItem {
    enum Status {
        case disabled
        case enabled
        case requiresApproval
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    static func register() {
        guard SMAppService.mainApp.status != .enabled else { return }
        try? SMAppService.mainApp.register()
    }

    static func unregister() {
        guard SMAppService.mainApp.status != .notRegistered else { return }
        try? SMAppService.mainApp.unregister()
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
