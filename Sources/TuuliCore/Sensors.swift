import Foundation

public enum SensorCategory: String, CaseIterable, Codable, Sendable {
    case cpuPerformance
    case cpuEfficiency
    case gpu
    case ssd
    case battery
    case wireless
    case ambient
    case surface
    case other

    public var title: String {
        switch self {
        case .cpuPerformance: "CPU Performance"
        case .cpuEfficiency: "CPU Efficiency"
        case .gpu: "GPU"
        case .ssd: "SSD"
        case .battery: "Battery"
        case .wireless: "Wireless"
        case .ambient: "Ambient"
        case .surface: "Surface"
        case .other: "Other"
        }
    }

    public var isCPU: Bool { self == .cpuPerformance || self == .cpuEfficiency }
}

public struct Sensor: Sendable, Hashable, Identifiable, Codable {
    /// The SMC key, e.g. `Tp1C`.
    public let id: String
    public let name: String
    public let category: SensorCategory

    public init(id: String, name: String, category: SensorCategory) {
        self.id = id
        self.name = name
        self.category = category
    }
}

/// Classifies SMC temperature keys by prefix. Key names differ between chips, so sensors
/// are discovered at runtime and grouped generically instead of relying on per-model lists.
public enum SensorCatalog {
    public static let plausibleRange = 10.0...130.0

    /// Prefixes whose `flt` values are not temperatures (flow rates, offsets, calibration).
    private static let excludedPrefixes = ["Tf", "Tz", "TR"]

    private static let prefixes: [(String, SensorCategory)] = [
        ("Tp", .cpuPerformance),
        ("Te", .cpuEfficiency),
        ("Tg", .gpu),
        ("TH", .ssd),
        ("TB", .battery),
        ("TW", .wireless),
        ("TA", .ambient),
        ("Ts", .surface),
        ("Ta", .surface),
    ]

    /// Category for a key, or nil when the key should not be treated as a temperature.
    public static func category(forKey key: String) -> SensorCategory? {
        guard key.count == 4, key.hasPrefix("T") else { return nil }
        if excludedPrefixes.contains(where: key.hasPrefix) { return nil }
        return prefixes.first { key.hasPrefix($0.0) }?.1 ?? .other
    }

    public static func isPlausible(_ value: Double) -> Bool {
        plausibleRange.contains(value)
    }

    /// Builds sensors from `(key, value)` samples, numbering them per category in key order.
    public static func sensors(from samples: [(key: String, value: Double)]) -> [Sensor] {
        var counters: [SensorCategory: Int] = [:]
        return samples
            .filter { isPlausible($0.value) }
            .compactMap { sample -> (String, SensorCategory)? in
                category(forKey: sample.key).map { (sample.key, $0) }
            }
            .sorted { $0.0 < $1.0 }
            .map { key, category in
                counters[category, default: 0] += 1
                return Sensor(id: key, name: "\(category.title) \(counters[category]!)", category: category)
            }
    }
}

/// Summary values computed over groups of sensors. Referenced in settings as `@<rawValue>`.
public enum Aggregate: String, CaseIterable, Codable, Sendable {
    case hottest
    case cpuHottest
    case cpuAverage
    case gpuHottest
    case ssdHottest
    case batteryHottest

    public var title: String {
        switch self {
        case .hottest: "Hottest Sensor"
        case .cpuHottest: "CPU Hottest"
        case .cpuAverage: "CPU Average"
        case .gpuHottest: "GPU Hottest"
        case .ssdHottest: "SSD"
        case .batteryHottest: "Battery"
        }
    }

    public var shortTitle: String {
        switch self {
        case .hottest: "Max"
        case .cpuHottest: "CPU"
        case .cpuAverage: "CPU avg"
        case .gpuHottest: "GPU"
        case .ssdHottest: "SSD"
        case .batteryHottest: "Batt"
        }
    }

    public var sensorID: String { "@" + rawValue }

    public func value(sensors: [Sensor], readings: [String: Double]) -> Double? {
        let values: [Double] = sensors.compactMap { sensor in
            guard includes(sensor.category) else { return nil }
            return readings[sensor.id]
        }
        guard !values.isEmpty else { return nil }
        if self == .cpuAverage {
            return values.reduce(0, +) / Double(values.count)
        }
        return values.max()
    }

    private func includes(_ category: SensorCategory) -> Bool {
        switch self {
        case .hottest: category != .other
        case .cpuHottest, .cpuAverage: category.isCPU
        case .gpuHottest: category == .gpu
        case .ssdHottest: category == .ssd
        case .batteryHottest: category == .battery
        }
    }
}

/// A point-in-time reading of every discovered sensor, plus the aggregates.
public struct SensorSnapshot: Sendable {
    public let date: Date
    public let readings: [String: Double]

    public init(date: Date, sensors: [Sensor], raw: [String: Double]) {
        var readings = raw
        for aggregate in Aggregate.allCases {
            if let value = aggregate.value(sensors: sensors, readings: raw) {
                readings[aggregate.sensorID] = value
            }
        }
        self.date = date
        self.readings = readings
    }

    /// Value for a sensor ID (an SMC key or an `@aggregate`).
    public subscript(id: String) -> Double? { readings[id] }
}

extension SMC {
    /// Discovers temperature sensors, reading every `T…` key of type `flt `.
    public func discoverSensors() -> [Sensor] {
        let samples: [(key: String, value: Double)] = allKeys().compactMap { key in
            guard SensorCatalog.category(forKey: key) != nil,
                  info(key)?.type == "flt ",
                  let value = read(key) else { return nil }
            return (key, value)
        }
        return SensorCatalog.sensors(from: samples)
    }

    public func readTemperatures(_ sensors: [Sensor]) -> [String: Double] {
        var readings: [String: Double] = [:]
        for sensor in sensors {
            if let value = read(sensor.id), SensorCatalog.isPlausible(value) {
                readings[sensor.id] = value
            }
        }
        return readings
    }
}
