import Foundation
import IOKit.pwr_mgt
import Security
import TuuliCore

/// Only accepts connections from the Tuuli app, signed by the same team as this helper.
final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let service: HelperService

    init(service: HelperService) {
        self.service = service
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: TuuliHelperProtocol.self)
        connection.exportedObject = service
        connection.invalidationHandler = { [service] in service.connectionClosed() }
        connection.resume()
        return true
    }
}

func ownTeamIdentifier() -> String? {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var info: CFDictionary?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
          SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
          SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
    else { return nil }
    return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
}

func clientRequirement() -> String {
    let identifier = "identifier \"\(HelperConstants.appBundleID)\""
    guard let team = ownTeamIdentifier() else { return identifier }
    return "\(identifier) and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
}

let service = HelperService()
let delegate = ListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: HelperConstants.label)
listener.setConnectionCodeSigningRequirement(clientRequirement())
listener.delegate = delegate
listener.resume()

// iokit_common_msg(0x280) and iokit_common_msg(0x270), not imported into Swift.
let systemWillSleep: UInt32 = 0xE000_0280
let canSystemSleep: UInt32 = 0xE000_0270

// Give the fans back before the system sleeps; the app takes over again after wake.
nonisolated(unsafe) var rootPort: io_connect_t = 0
var notifier: io_object_t = 0
var notifyPort: IONotificationPortRef?
rootPort = IORegisterForSystemPower(nil, &notifyPort, { _, _, messageType, argument in
    switch messageType {
    case systemWillSleep:
        service.restoreNow()
        IOAllowPowerChange(rootPort, Int(bitPattern: argument))
    case canSystemSleep:
        IOAllowPowerChange(rootPort, Int(bitPattern: argument))
    default:
        break
    }
}, &notifier)
if let notifyPort {
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue(), .commonModes)
}

signal(SIGTERM, SIG_IGN)
let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    service.restoreNow()
    exit(0)
}
termination.resume()

RunLoop.main.run()
