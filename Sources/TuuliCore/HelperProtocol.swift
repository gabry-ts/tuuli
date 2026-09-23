import Foundation

public enum HelperConstants {
    public static let label = "com.gabrielepartiti.tuuli.helper"
    public static let appBundleID = "com.gabrielepartiti.tuuli"
    /// Bumped whenever the helper's behavior changes, so the app can offer an update.
    public static let version = "1"
    public static let installedBinary = "/Library/PrivilegedHelperTools/\(label)"
    public static let installedPlist = "/Library/LaunchDaemons/\(label).plist"
    /// Seconds without contact from the app before fans go back to the system.
    public static let watchdogTimeout: TimeInterval = 10
}

/// XPC interface of the root helper. It only ever writes fan keys; all decisions are
/// made by the app, which must keep calling `setFanSpeeds` to hold manual control.
@objc public protocol TuuliHelperProtocol {
    func version(reply: @escaping @Sendable (String) -> Void)
    /// Target RPM per fan index. Fans beyond the array keep their current mode.
    func setFanSpeeds(_ rpms: [NSNumber], reply: @escaping @Sendable (String?) -> Void)
    func restoreAutomatic(reply: @escaping @Sendable (String?) -> Void)
}
