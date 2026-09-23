import Foundation

public struct FanStatus: Sendable, Hashable, Identifiable {
    public let id: Int
    public let current: Double
    public let minimum: Double
    public let maximum: Double
    public let isManual: Bool

    public init(id: Int, current: Double, minimum: Double, maximum: Double, isManual: Bool) {
        self.id = id
        self.current = current
        self.minimum = minimum
        self.maximum = maximum
        self.isManual = isManual
    }

    public var name: String { "Fan \(id + 1)" }

    /// RPM for a 0–100 speed percentage within this fan's range.
    public func rpm(forPercent percent: Double) -> Double {
        let p = min(max(percent, 0), 100) / 100
        return (minimum + p * (maximum - minimum)).rounded()
    }

    /// Current speed as a 0–100 percentage of the range; 0 when stopped or below minimum.
    public var percent: Double {
        guard maximum > minimum, current > 0 else { return 0 }
        return min(max((current - minimum) / (maximum - minimum) * 100, 0), 100)
    }
}

extension SMC {
    public var fanCount: Int {
        Int(read("FNum") ?? 0)
    }

    public func readFans() -> [FanStatus] {
        (0..<fanCount).compactMap { i in
            guard let minimum = read("F\(i)Mn"), let maximum = read("F\(i)Mx") else { return nil }
            return FanStatus(
                id: i,
                current: read("F\(i)Ac") ?? 0,
                minimum: minimum,
                maximum: maximum,
                isManual: (read("F\(i)Md") ?? 0) == 1
            )
        }
    }

    /// Forces a fan to a target RPM. Requires root. Some Apple Silicon firmwares refuse
    /// manual mode until the `Ftst` test flag is raised, so that is tried as a fallback.
    public func setFanTarget(_ fan: Int, rpm: Double) throws {
        if read("F\(fan)Md") != 1 {
            do {
                try write("F\(fan)Md", value: 1)
            } catch {
                guard info("Ftst") != nil else { throw error }
                try write("Ftst", value: 1)
                try retry(for: 3) { try self.write("F\(fan)Md", value: 1) }
            }
        }
        try write("F\(fan)Tg", value: rpm)
    }

    /// Hands every fan back to the system controller. Requires root.
    public func restoreAutomaticFans() throws {
        var firstError: Error?
        for fan in 0..<fanCount {
            do { try write("F\(fan)Md", value: 0) } catch { firstError = firstError ?? error }
        }
        if info("Ftst") != nil, read("Ftst") != 0 {
            do { try write("Ftst", value: 0) } catch { firstError = firstError ?? error }
        }
        if let firstError { throw firstError }
    }

    private func retry(for seconds: Double, _ body: () throws -> Void) throws {
        let deadline = Date().addingTimeInterval(seconds)
        while true {
            do { return try body() } catch {
                if Date() > deadline { throw error }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
}
