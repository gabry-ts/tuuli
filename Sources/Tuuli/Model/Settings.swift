import Foundation
import TuuliCore

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit

    var symbol: String { self == .celsius ? "°C" : "°F" }

    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    /// Full reading for lists, e.g. "54.2 °C".
    func format(_ celsius: Double?) -> String {
        guard let celsius else { return "–" }
        return String(format: "%.1f %@", convert(celsius), symbol)
    }

    /// Compact reading for the menu bar, e.g. "54°".
    func short(_ celsius: Double?) -> String {
        guard let celsius else { return "–°" }
        return "\(Int(convert(celsius).rounded()))°"
    }
}

struct AlertRule: Codable, Hashable, Identifiable {
    var id = UUID()
    var isEnabled = true
    var sensor: String
    var threshold: Double
}

struct MenuBarSettings: Codable, Hashable {
    var showIcon = true
    var primarySensor: String? = Aggregate.cpuHottest.sensorID
    var secondarySensor: String?
    var showFanSpeed = false
}

struct LoggingSettings: Codable, Hashable {
    var isEnabled = false
    var interval: Double = 5
    var folderPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
}

struct Settings: Codable, Hashable {
    var pollInterval: Double = 2
    var unit: TemperatureUnit = .celsius
    var adapterConfig = FanConfig.boost(threshold: 65)
    var batteryConfig = FanConfig.boost(threshold: 70)
    var separateBatteryConfig = true
    var menuBar = MenuBarSettings()
    var alerts: [AlertRule] = [AlertRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 95)]
    var alertCooldownMinutes: Double = 5
    var alertSound = false
    var logging = LoggingSettings()
    var historyMinutes = 15
    var showAllSensors = false

    init() {}

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        pollInterval = try c.decodeIfPresent(Double.self, forKey: .pollInterval) ?? d.pollInterval
        unit = try c.decodeIfPresent(TemperatureUnit.self, forKey: .unit) ?? d.unit
        adapterConfig = try c.decodeIfPresent(FanConfig.self, forKey: .adapterConfig) ?? d.adapterConfig
        batteryConfig = try c.decodeIfPresent(FanConfig.self, forKey: .batteryConfig) ?? d.batteryConfig
        separateBatteryConfig = try c.decodeIfPresent(Bool.self, forKey: .separateBatteryConfig) ?? d.separateBatteryConfig
        menuBar = try c.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar) ?? d.menuBar
        alerts = try c.decodeIfPresent([AlertRule].self, forKey: .alerts) ?? d.alerts
        alertCooldownMinutes = try c.decodeIfPresent(Double.self, forKey: .alertCooldownMinutes) ?? d.alertCooldownMinutes
        alertSound = try c.decodeIfPresent(Bool.self, forKey: .alertSound) ?? d.alertSound
        logging = try c.decodeIfPresent(LoggingSettings.self, forKey: .logging) ?? d.logging
        historyMinutes = try c.decodeIfPresent(Int.self, forKey: .historyMinutes) ?? d.historyMinutes
        showAllSensors = try c.decodeIfPresent(Bool.self, forKey: .showAllSensors) ?? d.showAllSensors
    }

    func fanConfig(onBattery: Bool) -> FanConfig {
        separateBatteryConfig && onBattery ? batteryConfig : adapterConfig
    }
}

extension FanConfig {
    /// Default: full speed, ramped in over 10 seconds, once the CPU reaches `threshold`.
    static func boost(threshold: Double) -> FanConfig {
        var config = FanConfig()
        config.mode = .boost
        config.rules = [BoostRule(sensor: Aggregate.cpuHottest.sensorID, threshold: threshold, percent: 100)]
        config.rampSeconds = 10
        return config
    }
}
