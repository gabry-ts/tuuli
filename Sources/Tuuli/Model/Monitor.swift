import Foundation
import Observation
import TuuliCore

struct HistorySample: Identifiable {
    let date: Date
    /// Aggregates by sensor ID and fan speeds keyed `fan0`, `fan1`…
    let values: [String: Double]

    var id: Date { date }
}

/// Polls the SMC for temperatures and fan speeds and keeps a rolling history.
@MainActor
@Observable
final class Monitor {
    private(set) var sensors: [Sensor] = []
    private(set) var snapshot = SensorSnapshot(date: .now, sensors: [], raw: [:])
    private(set) var fans: [FanStatus] = []
    private(set) var history: [HistorySample] = []
    private(set) var isOnBattery = false
    private(set) var smcError: String?

    /// Called after every sample, for the fan engine, alerts and logging.
    var onSample: (() -> Void)?

    static let historyLimit: TimeInterval = 60 * 60

    private let smc: SMC?
    private var timer: Timer?

    init() {
        do {
            smc = try SMC()
        } catch {
            smc = nil
            smcError = "\(error)"
        }
    }

    /// Mock monitor for offscreen snapshots.
    init(sensors: [Sensor], raw: [String: Double], fans: [FanStatus], history: [HistorySample]) {
        smc = nil
        self.sensors = sensors
        self.snapshot = SensorSnapshot(date: .now, sensors: sensors, raw: raw)
        self.fans = fans
        self.history = history
    }

    func start(interval: TimeInterval) {
        if sensors.isEmpty, let smc {
            sensors = smc.discoverSensors()
        }
        sample()
        schedule(interval: interval)
    }

    func schedule(interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func value(_ sensorID: String) -> Double? {
        snapshot[sensorID]
    }

    func name(of sensorID: String) -> String {
        if sensorID.hasPrefix("@"), let aggregate = Aggregate(rawValue: String(sensorID.dropFirst())) {
            return aggregate.title
        }
        return sensors.first { $0.id == sensorID }?.name ?? sensorID
    }

    func shortName(of sensorID: String) -> String {
        if sensorID.hasPrefix("@"), let aggregate = Aggregate(rawValue: String(sensorID.dropFirst())) {
            return aggregate.shortTitle
        }
        return sensorID
    }

    /// Aggregates that have at least one sensor on this Mac.
    var availableAggregates: [Aggregate] {
        Aggregate.allCases.filter { snapshot[$0.sensorID] != nil }
    }

    private func sample() {
        guard let smc else { return }
        let now = Date()
        snapshot = SensorSnapshot(date: now, sensors: sensors, raw: smc.readTemperatures(sensors))
        fans = smc.readFans()
        isOnBattery = PowerSource.isOnBattery

        var values: [String: Double] = [:]
        for aggregate in Aggregate.allCases {
            values[aggregate.sensorID] = snapshot[aggregate.sensorID]
        }
        for fan in fans {
            values["fan\(fan.id)"] = fan.current
        }
        history.append(HistorySample(date: now, values: values))
        if let first = history.first, now.timeIntervalSince(first.date) > Self.historyLimit {
            history.removeAll { now.timeIntervalSince($0.date) > Self.historyLimit }
        }
        onSample?()
    }
}
