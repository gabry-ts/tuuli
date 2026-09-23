import Foundation
import Observation
import TuuliCore

/// Applies the active fan config on every sample, through the helper.
@MainActor
@Observable
final class FanEngine {
    /// Speed Tuuli is currently asking for, nil when the system is in control.
    private(set) var targetPercent: Double?

    private var policy = FanPolicy()
    private var lastTick: Date?
    private var isHolding = false
    private var lastConfig: FanConfig?

    func tick(monitor: Monitor, settings: Settings, helper: HelperClient) {
        let config = settings.activeProfile(onBattery: monitor.isOnBattery).config
        if config != lastConfig {
            policy.reset()
            lastConfig = config
        }
        let now = Date()
        let elapsed = lastTick.map { now.timeIntervalSince($0) } ?? settings.pollInterval
        lastTick = now

        guard helper.isReady, !monitor.fans.isEmpty else {
            targetPercent = nil
            return
        }

        let currentPercent = monitor.fans.map(\.percent).max() ?? 0
        let percent = policy.step(
            config: config,
            reading: { monitor.value($0) },
            currentPercent: currentPercent,
            elapsed: elapsed
        )
        targetPercent = percent

        if let percent {
            helper.setFanSpeeds(monitor.fans.map { $0.rpm(forPercent: percent) })
            isHolding = true
        } else if isHolding {
            helper.restoreAutomatic()
            isHolding = false
        }
    }

    /// Gives the fans back immediately, e.g. when quitting.
    func release(helper: HelperClient) {
        policy.reset()
        targetPercent = nil
        if isHolding {
            helper.restoreAutomatic()
            isHolding = false
        }
    }
}
