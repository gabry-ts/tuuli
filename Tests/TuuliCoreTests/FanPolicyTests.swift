import XCTest
@testable import TuuliCore

final class FanPolicyTests: XCTestCase {
    private func config(_ mode: FanMode) -> FanConfig {
        var config = FanConfig()
        config.mode = mode
        config.rampSeconds = 0
        return config
    }

    func testSystemModeReleasesFans() {
        var policy = FanPolicy()
        XCTAssertNil(policy.step(config: config(.system), reading: { _ in 99 }, currentPercent: 0, elapsed: 1))
    }

    func testManualIgnoresRamp() {
        var policy = FanPolicy()
        var config = config(.manual)
        config.manualPercent = 40
        config.rampSeconds = 100
        XCTAssertEqual(policy.step(config: config, reading: { _ in nil }, currentPercent: 0, elapsed: 1), 40)
    }

    func testCurveInterpolation() {
        let points = [CurvePoint(temperature: 50, percent: 0), CurvePoint(temperature: 70, percent: 100)]
        XCTAssertEqual(FanCurve.percent(at: 40, points: points), 0)
        XCTAssertEqual(FanCurve.percent(at: 60, points: points), 50)
        XCTAssertEqual(FanCurve.percent(at: 90, points: points), 100)
    }

    func testCurveAtZeroHandsBackToSystem() {
        var policy = FanPolicy()
        XCTAssertNil(policy.step(config: config(.curve), reading: { _ in 30 }, currentPercent: 0, elapsed: 1))
        XCTAssertNotNil(policy.step(config: config(.curve), reading: { _ in 85 }, currentPercent: 0, elapsed: 1))
    }

    func testBoostHysteresis() {
        var policy = FanPolicy()
        var config = config(.boost)
        config.rules = [BoostRule(sensor: "@cpuHottest", threshold: 65, percent: 100)]
        config.hysteresis = 3
        var temp = 64.0
        let step = { policy.step(config: config, reading: { _ in temp }, currentPercent: 0, elapsed: 1) }
        XCTAssertNil(step())
        temp = 65
        XCTAssertEqual(step(), 100)
        temp = 63
        XCTAssertEqual(step(), 100)
        temp = 62
        XCTAssertNil(step())
    }

    func testBoostPicksHighestActiveRule() {
        var policy = FanPolicy()
        var config = config(.boost)
        config.rules = [
            BoostRule(sensor: "a", threshold: 50, percent: 40),
            BoostRule(sensor: "b", threshold: 50, percent: 80),
            BoostRule(isEnabled: false, sensor: "a", threshold: 10, percent: 100),
        ]
        XCTAssertEqual(policy.step(config: config, reading: { _ in 60 }, currentPercent: 0, elapsed: 1), 80)
    }

    func testRampLimitsChangePerSecond() {
        var policy = FanPolicy()
        var config = config(.boost)
        config.rules = [BoostRule(sensor: "a", threshold: 50, percent: 100)]
        config.rampSeconds = 10
        XCTAssertEqual(policy.step(config: config, reading: { _ in 60 }, currentPercent: 20, elapsed: 2), 40)
        XCTAssertEqual(policy.step(config: config, reading: { _ in 60 }, currentPercent: 20, elapsed: 2), 60)
    }

    func testFanPercentToRPM() {
        let fan = FanStatus(id: 0, current: 0, minimum: 2317, maximum: 6800, isManual: false)
        XCTAssertEqual(fan.rpm(forPercent: 0), 2317)
        XCTAssertEqual(fan.rpm(forPercent: 100), 6800)
        XCTAssertEqual(fan.percent, 0)
    }
}
