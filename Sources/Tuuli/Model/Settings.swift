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

/// What the menu bar popover shows, top to bottom.
struct PopoverSettings: Codable, Hashable {
    var showTemperatures = true
    var temperatureSensors = [
        Aggregate.cpuHottest.sensorID,
        Aggregate.gpuHottest.sensorID,
        Aggregate.ssdHottest.sensorID,
        Aggregate.batteryHottest.sensorID,
    ]
    var showFans = true
    var showProfilePicker = true
    var showChart = true
    var chartSensor = Aggregate.cpuHottest.sensorID
    var chartMinutes = 5
}

struct LoggingSettings: Codable, Hashable {
    var isEnabled = false
    var interval: Double = 5
    var folderPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
}

struct FanProfile: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var config: FanConfig
}

struct Settings: Codable, Hashable {
    var pollInterval: Double = 2
    var unit: TemperatureUnit = .celsius
    var profiles: [FanProfile]
    var adapterProfileID: UUID
    var batteryProfileID: UUID
    /// Profile picked by hand from the menu bar. Cleared when the power source changes.
    var overrideProfileID: UUID?
    var menuBar = MenuBarSettings()
    var popover = PopoverSettings()
    var alerts: [AlertRule] = [AlertRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 95)]
    var alertCooldownMinutes: Double = 5
    var alertSound = false
    var logging = LoggingSettings()
    var historyMinutes = 15
    var showAllSensors = false

    init() {
        self.init(adapter: .boost(threshold: 65), battery: .boost(threshold: 70))
    }

    private init(adapter: FanConfig, battery: FanConfig) {
        let adapterProfile = FanProfile(name: "Power Adapter", config: adapter)
        let batteryProfile = FanProfile(name: "Battery", config: battery)
        profiles = [adapterProfile, batteryProfile]
        adapterProfileID = adapterProfile.id
        batteryProfileID = batteryProfile.id
    }

    /// Keys from before profiles existed.
    private enum LegacyKeys: String, CodingKey {
        case adapterConfig, batteryConfig, separateBatteryConfig
    }

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let profiles = try c.decodeIfPresent([FanProfile].self, forKey: .profiles), !profiles.isEmpty {
            self.init()
            self.profiles = profiles
            adapterProfileID = try c.decodeIfPresent(UUID.self, forKey: .adapterProfileID) ?? profiles[0].id
            batteryProfileID = try c.decodeIfPresent(UUID.self, forKey: .batteryProfileID) ?? profiles[0].id
            overrideProfileID = try c.decodeIfPresent(UUID.self, forKey: .overrideProfileID)
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let adapter = try legacy.decodeIfPresent(FanConfig.self, forKey: .adapterConfig) ?? .boost(threshold: 65)
            let battery = try legacy.decodeIfPresent(FanConfig.self, forKey: .batteryConfig) ?? .boost(threshold: 70)
            self.init(adapter: adapter, battery: battery)
            if try legacy.decodeIfPresent(Bool.self, forKey: .separateBatteryConfig) == false {
                batteryProfileID = adapterProfileID
            }
        }
        let d = Settings()
        pollInterval = try c.decodeIfPresent(Double.self, forKey: .pollInterval) ?? d.pollInterval
        unit = try c.decodeIfPresent(TemperatureUnit.self, forKey: .unit) ?? d.unit
        menuBar = try c.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar) ?? d.menuBar
        popover = try c.decodeIfPresent(PopoverSettings.self, forKey: .popover) ?? d.popover
        alerts = try c.decodeIfPresent([AlertRule].self, forKey: .alerts) ?? d.alerts
        alertCooldownMinutes = try c.decodeIfPresent(Double.self, forKey: .alertCooldownMinutes) ?? d.alertCooldownMinutes
        alertSound = try c.decodeIfPresent(Bool.self, forKey: .alertSound) ?? d.alertSound
        logging = try c.decodeIfPresent(LoggingSettings.self, forKey: .logging) ?? d.logging
        historyMinutes = try c.decodeIfPresent(Int.self, forKey: .historyMinutes) ?? d.historyMinutes
        showAllSensors = try c.decodeIfPresent(Bool.self, forKey: .showAllSensors) ?? d.showAllSensors
        repairProfileReferences()
    }

    /// ID of the profile assigned to the power source, ignoring any manual override.
    func automaticProfileID(onBattery: Bool) -> UUID {
        onBattery ? batteryProfileID : adapterProfileID
    }

    func activeProfileID(onBattery: Bool) -> UUID {
        overrideProfileID ?? automaticProfileID(onBattery: onBattery)
    }

    func activeProfile(onBattery: Bool) -> FanProfile {
        let id = activeProfileID(onBattery: onBattery)
        return profiles.first { $0.id == id } ?? profiles[0]
    }

    func index(of profileID: UUID) -> Int? {
        profiles.firstIndex { $0.id == profileID }
    }

    /// Points dangling assignments (after a delete) back at the first profile.
    mutating func repairProfileReferences() {
        let ids = Set(profiles.map(\.id))
        if !ids.contains(adapterProfileID) { adapterProfileID = profiles[0].id }
        if !ids.contains(batteryProfileID) { batteryProfileID = profiles[0].id }
        if let override = overrideProfileID, !ids.contains(override) { overrideProfileID = nil }
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
