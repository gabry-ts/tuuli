import Foundation
import TuuliCore

/// Owns the SMC connection and the fail-safe: fans go back to the system when the app
/// stops calling in, disconnects, the Mac sleeps, or the helper is terminated.
final class HelperService: NSObject, TuuliHelperProtocol, @unchecked Sendable {
    private let smc: SMC?
    private let queue = DispatchQueue(label: "com.gabrielepartiti.tuuli.helper.fans")
    private var lastContact = Date.distantPast
    private var isHoldingFans = false
    private var watchdog: DispatchSourceTimer?

    override init() {
        smc = try? SMC()
        super.init()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.checkWatchdog() }
        timer.resume()
        watchdog = timer
        // A previous instance may have died while holding the fans.
        queue.sync { _ = restoreLocked() }
    }

    func version(reply: @escaping @Sendable (String) -> Void) {
        reply(HelperConstants.version)
    }

    func setFanSpeeds(_ rpms: [NSNumber], reply: @escaping @Sendable (String?) -> Void) {
        queue.async { [self] in
            guard let smc else { return reply("SMC unavailable") }
            lastContact = Date()
            isHoldingFans = true
            let fans = smc.readFans()
            var failure: String?
            for (index, rpm) in rpms.enumerated() where index < fans.count {
                let fan = fans[index]
                let target = min(max(rpm.doubleValue, fan.minimum), fan.maximum)
                do {
                    try smc.setFanTarget(index, rpm: target)
                } catch {
                    failure = failure ?? "\(error)"
                }
            }
            reply(failure)
        }
    }

    func restoreAutomatic(reply: @escaping @Sendable (String?) -> Void) {
        queue.async { [self] in
            lastContact = Date()
            reply(restoreLocked())
        }
    }

    /// Synchronous restore for sleep and termination paths.
    func restoreNow() {
        queue.sync { _ = restoreLocked() }
    }

    func connectionClosed() {
        queue.async { [self] in _ = restoreLocked() }
    }

    @discardableResult
    private func restoreLocked() -> String? {
        isHoldingFans = false
        guard let smc else { return "SMC unavailable" }
        do {
            try smc.restoreAutomaticFans()
            return nil
        } catch {
            return "\(error)"
        }
    }

    private func checkWatchdog() {
        guard isHoldingFans, Date().timeIntervalSince(lastContact) > HelperConstants.watchdogTimeout else { return }
        restoreLocked()
    }
}
