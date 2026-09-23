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

/// One piece of the status item, shown left to right in list order.
enum StatusElement: Codable, Hashable {
    case icon
    case temperature(String)
    case fanSpeed
}

struct MenuBarSettings: Codable, Hashable {
    var items: [StatusElement] = [.icon, .temperature(Aggregate.cpuHottest.sensorID)]

    init() {}

    private enum LegacyKeys: String, CodingKey {
        case showIcon, primarySensor, secondarySensor, showFanSpeed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try c.decodeIfPresent([StatusElement].self, forKey: .items) {
            self.items = items
            return
        }
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        var items: [StatusElement] = []
        if try legacy.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true { items.append(.icon) }
        for key in [LegacyKeys.primarySensor, .secondarySensor] {
            if let sensor = try legacy.decodeIfPresent(String.self, forKey: key) { items.append(.temperature(sensor)) }
        }
        if try legacy.decodeIfPresent(Bool.self, forKey: .showFanSpeed) ?? false { items.append(.fanSpeed) }
        self.items = items
    }
}

enum PopoverSection: String, Codable, CaseIterable {
    case temperatures
    case chart
    case fans
    case modePicker

    var title: String {
        switch self {
        case .temperatures: "Temperatures"
        case .chart: "Chart"
        case .fans: "Fan speeds"
        case .modePicker: "Mode picker"
        }
    }
}

struct PopoverEntry: Codable, Hashable {
    var section: PopoverSection
    var isEnabled = true
}

/// What the menu bar popover shows, top to bottom in `sections` order.
struct PopoverSettings: Codable, Hashable {
    var sections = PopoverSection.allCases.map { PopoverEntry(section: $0) }
    var temperatureSensors = [
        Aggregate.cpuHottest.sensorID,
        Aggregate.gpuHottest.sensorID,
        Aggregate.ssdHottest.sensorID,
        Aggregate.batteryHottest.sensorID,
    ]
    var chartSensor = Aggregate.cpuHottest.sensorID
    var chartMinutes = 5

    init() {}

    private enum LegacyKeys: String, CodingKey {
        case showTemperatures, showChart, showFans, showProfilePicker
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PopoverSettings()
        temperatureSensors = try c.decodeIfPresent([String].self, forKey: .temperatureSensors) ?? d.temperatureSensors
        chartSensor = try c.decodeIfPresent(String.self, forKey: .chartSensor) ?? d.chartSensor
        chartMinutes = try c.decodeIfPresent(Int.self, forKey: .chartMinutes) ?? d.chartMinutes
        if let sections = try c.decodeIfPresent([PopoverEntry].self, forKey: .sections) {
            // Sections added in later versions are appended, enabled.
            let missing = PopoverSection.allCases.filter { section in !sections.contains { $0.section == section } }
            self.sections = sections + missing.map { PopoverEntry(section: $0) }
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let flags: [PopoverSection: LegacyKeys] = [
                .temperatures: .showTemperatures, .chart: .showChart, .fans: .showFans, .modePicker: .showProfilePicker,
            ]
            sections = try PopoverSection.allCases.map { section in
                PopoverEntry(section: section, isEnabled: try legacy.decodeIfPresent(Bool.self, forKey: flags[section]!) ?? true)
            }
        }
    }
}

struct LoggingSettings: Codable, Hashable {
    var isEnabled = false
    var interval: Double = 5
    var folderPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
}

/// A named fan mode. The four built-ins can be renamed but not deleted; custom modes
/// pick their own kind. Boost and curve modes can differ on battery.
struct Mode: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var kind: FanMode
    var isBuiltIn = false
    var adapter = FanConfig()
    var battery = FanConfig()
    var sameOnBattery = true

    var hasBatterySettings: Bool { kind == .boost || kind == .curve }

    func config(onBattery: Bool) -> FanConfig {
        var config = onBattery && !sameOnBattery && hasBatterySettings ? battery : adapter
        config.mode = kind
        return config
    }

    static func builtIns() -> [Mode] {
        var manual = FanConfig()
        manual.manualPercent = 50
        return [
            Mode(name: "System", kind: .system, isBuiltIn: true),
            Mode(name: "Auto Boost", kind: .boost, isBuiltIn: true,
                 adapter: .boost(threshold: 65), battery: .boost(threshold: 70), sameOnBattery: false),
            Mode(name: "Curve", kind: .curve, isBuiltIn: true),
            Mode(name: "Manual", kind: .manual, isBuiltIn: true, adapter: manual, battery: manual),
        ]
    }
}

struct Settings: Codable, Hashable {
    var pollInterval: Double = 2
    var unit: TemperatureUnit = .celsius
    var modes = Mode.builtIns()
    var activeModeID: UUID
    var menuBar = MenuBarSettings()
    var popover = PopoverSettings()
    var alerts: [AlertRule] = [AlertRule(sensor: Aggregate.cpuHottest.sensorID, threshold: 95)]
    var alertCooldownMinutes: Double = 5
    var alertSound = false
    var logging = LoggingSettings()
    var historyMinutes = 15
    var showAllSensors = false

    init() {
        activeModeID = modes[1].id
    }

    /// Keys from before modes existed: a per-power-source config, then named profiles.
    private enum LegacyKeys: String, CodingKey {
        case adapterConfig, batteryConfig, profiles, adapterProfileID, batteryProfileID
    }

    private struct LegacyProfile: Decodable {
        var id: UUID
        var config: FanConfig
    }

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let modes = try c.decodeIfPresent([Mode].self, forKey: .modes), !modes.isEmpty {
            self.modes = modes
            activeModeID = try c.decodeIfPresent(UUID.self, forKey: .activeModeID) ?? modes[0].id
        } else {
            try migrateBoostRules(from: decoder.container(keyedBy: LegacyKeys.self))
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
        if !modes.contains(where: { $0.id == activeModeID }) { activeModeID = modes[0].id }
    }

    /// Carries older power adapter and battery boost rules into the built-in Auto Boost mode.
    private mutating func migrateBoostRules(from legacy: KeyedDecodingContainer<LegacyKeys>) throws {
        var adapter = try legacy.decodeIfPresent(FanConfig.self, forKey: .adapterConfig)
        var battery = try legacy.decodeIfPresent(FanConfig.self, forKey: .batteryConfig)
        if let profiles = try legacy.decodeIfPresent([LegacyProfile].self, forKey: .profiles) {
            let adapterID = try legacy.decodeIfPresent(UUID.self, forKey: .adapterProfileID)
            let batteryID = try legacy.decodeIfPresent(UUID.self, forKey: .batteryProfileID)
            adapter = profiles.first { $0.id == adapterID }?.config ?? adapter
            battery = profiles.first { $0.id == batteryID }?.config ?? battery
        }
        guard let boost = modes.firstIndex(where: { $0.kind == .boost }) else { return }
        if let adapter, adapter.mode == .boost { modes[boost].adapter = adapter }
        if let battery, battery.mode == .boost { modes[boost].battery = battery }
    }

    var activeMode: Mode {
        modes.first { $0.id == activeModeID } ?? modes[0]
    }

    func index(of modeID: UUID) -> Int? {
        modes.firstIndex { $0.id == modeID }
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
