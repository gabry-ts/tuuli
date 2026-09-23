import Foundation
import Observation
import TuuliCore

/// Talks to the root helper over XPC and installs or removes it.
@MainActor
@Observable
final class HelperClient {
    enum Status: Equatable {
        case notInstalled
        case checking
        case ready
        case outdated(String)
        case unreachable
    }

    private(set) var status: Status = .checking
    private(set) var lastError: String?
    private var connection: NSXPCConnection?

    var isReady: Bool { status == .ready }

    func refresh() {
        guard FileManager.default.fileExists(atPath: HelperConstants.installedPlist) else {
            status = .notInstalled
            return
        }
        status = .checking
        proxy { [weak self] error in
            Task { @MainActor in self?.status = .unreachable }
        }?.version { version in
            Task { @MainActor [weak self] in
                self?.status = version == HelperConstants.version ? .ready : .outdated(version)
            }
        }
    }

    func setFanSpeeds(_ rpms: [Double]) {
        proxy { [weak self] error in
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }?.setFanSpeeds(rpms.map { NSNumber(value: $0) }) { error in
            Task { @MainActor [weak self] in self?.lastError = error }
        }
    }

    func restoreAutomatic() {
        proxy { _ in }?.restoreAutomatic { _ in }
    }

    // MARK: Install

    func install() {
        guard let helper = Bundle.main.url(forAuxiliaryExecutable: "TuuliHelper"),
              let plist = Bundle.main.url(forResource: HelperConstants.label, withExtension: "plist")
        else {
            lastError = "Helper files are missing from the app bundle."
            return
        }
        connection?.invalidate()
        connection = nil
        let label = HelperConstants.label
        let script = """
        launchctl bootout system/\(label) 2>/dev/null || true
        mkdir -p /Library/PrivilegedHelperTools
        install -o root -g wheel -m 755 \(quoted(helper.path)) \(quoted(HelperConstants.installedBinary))
        install -o root -g wheel -m 644 \(quoted(plist.path)) \(quoted(HelperConstants.installedPlist))
        launchctl bootstrap system \(quoted(HelperConstants.installedPlist))
        """
        runPrivileged(script)
    }

    func uninstall() {
        restoreAutomatic()
        connection?.invalidate()
        connection = nil
        let script = """
        launchctl bootout system/\(HelperConstants.label) 2>/dev/null || true
        rm -f \(quoted(HelperConstants.installedPlist)) \(quoted(HelperConstants.installedBinary))
        """
        runPrivileged(script)
    }

    private func runPrivileged(_ shell: String) {
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with prompt \"Tuuli needs to install its fan control helper.\" with administrator privileges"
        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        if let errorInfo, (errorInfo[NSAppleScript.errorNumber] as? Int) != -128 {
            lastError = errorInfo[NSAppleScript.errorMessage] as? String ?? "Installation failed."
        } else {
            lastError = nil
        }
        // launchd needs a moment to register the Mach service.
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            refresh()
        }
    }

    private func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: XPC

    private func proxy(_ onError: @escaping @Sendable (Error) -> Void) -> TuuliHelperProtocol? {
        if connection == nil {
            let connection = NSXPCConnection(machServiceName: HelperConstants.label, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: TuuliHelperProtocol.self)
            connection.invalidationHandler = { [weak self] in
                Task { @MainActor in self?.connection = nil }
            }
            connection.resume()
            self.connection = connection
        }
        return connection?.remoteObjectProxyWithErrorHandler(onError) as? TuuliHelperProtocol
    }
}
