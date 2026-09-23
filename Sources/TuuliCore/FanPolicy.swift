import Foundation

public enum FanMode: String, Codable, CaseIterable, Sendable {
    case system
    case boost
    case curve
    case manual

    public var title: String {
        switch self {
        case .system: "System"
        case .boost: "Auto Boost"
        case .curve: "Custom Curve"
        case .manual: "Manual"
        }
    }
}

/// "When `sensor` reaches `threshold`, run the fans at `percent`."
public struct BoostRule: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var isEnabled = true
    public var sensor: String
    public var threshold: Double
    public var percent: Double

    public init(isEnabled: Bool = true, sensor: String, threshold: Double, percent: Double) {
        self.isEnabled = isEnabled
        self.sensor = sensor
        self.threshold = threshold
        self.percent = percent
    }
}

public struct CurvePoint: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var temperature: Double
    public var percent: Double

    public init(temperature: Double, percent: Double) {
        self.temperature = temperature
        self.percent = percent
    }
}

public struct FanConfig: Codable, Hashable, Sendable {
    public var mode: FanMode = .system
    public var manualPercent: Double = 50
    public var rules: [BoostRule] = [BoostRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 70, percent: 100)]
    public var curveSensor: String = Aggregate.cpuHottest.sensorID
    public var curve: [CurvePoint] = [
        CurvePoint(temperature: 50, percent: 0),
        CurvePoint(temperature: 65, percent: 30),
        CurvePoint(temperature: 80, percent: 70),
        CurvePoint(temperature: 90, percent: 100),
    ]
    /// Seconds for a full 0→100% change. 0 applies changes instantly.
    public var rampSeconds: Double = 10
    /// Degrees below the threshold at which a boost rule releases.
    public var hysteresis: Double = 3

    public init() {}
}

public enum FanCurve {
    /// Linear interpolation over points sorted by temperature, clamped at both ends.
    public static func percent(at temperature: Double, points: [CurvePoint]) -> Double {
        let sorted = points.sorted { $0.temperature < $1.temperature }
        guard let first = sorted.first, let last = sorted.last else { return 0 }
        if temperature <= first.temperature { return first.percent }
        if temperature >= last.temperature { return last.percent }
        for (a, b) in zip(sorted, sorted.dropFirst()) where temperature <= b.temperature {
            guard b.temperature > a.temperature else { return b.percent }
            let t = (temperature - a.temperature) / (b.temperature - a.temperature)
            return a.percent + t * (b.percent - a.percent)
        }
        return last.percent
    }
}

/// Turns a config and live readings into a fan speed, one tick at a time.
/// A nil result means "leave the fans to the system".
public struct FanPolicy: Sendable {
    public private(set) var activeRules: Set<UUID> = []
    public private(set) var output: Double?

    public init() {}

    public mutating func reset() {
        activeRules = []
        output = nil
    }

    /// - Parameters:
    ///   - reading: value for a sensor ID.
    ///   - currentPercent: the fans' actual speed, used as the ramp start when taking over.
    ///   - elapsed: seconds since the previous tick.
    public mutating func step(
        config: FanConfig,
        reading: (String) -> Double?,
        currentPercent: Double,
        elapsed: Double
    ) -> Double? {
        let target: Double?
        var ramps = true
        switch config.mode {
        case .system:
            target = nil
        case .manual:
            target = config.manualPercent
            ramps = false
        case .curve:
            let percent = reading(config.curveSensor).map { FanCurve.percent(at: $0, points: config.curve) }
            target = (percent ?? 0) > 0 ? percent : nil
        case .boost:
            target = boostTarget(config: config, reading: reading)
        }

        guard let target else {
            if config.mode != .boost { activeRules = [] }
            output = nil
            return nil
        }
        guard ramps, config.rampSeconds > 0 else {
            output = target
            return target
        }
        let start = output ?? currentPercent
        let maxStep = 100 / config.rampSeconds * max(elapsed, 0)
        let next = start + min(max(target - start, -maxStep), maxStep)
        output = next
        return next
    }

    private mutating func boostTarget(config: FanConfig, reading: (String) -> Double?) -> Double? {
        var best: Double?
        var active: Set<UUID> = []
        for rule in config.rules where rule.isEnabled {
            guard let value = reading(rule.sensor) else { continue }
            let wasActive = activeRules.contains(rule.id)
            let isActive = wasActive ? value > rule.threshold - config.hysteresis : value >= rule.threshold
            if isActive {
                active.insert(rule.id)
                best = max(best ?? 0, rule.percent)
            }
        }
        activeRules = active
        return best
    }
}
