import XCTest
@testable import TuuliCore

final class SensorCatalogTests: XCTestCase {
    func testCategoriesByPrefix() {
        XCTAssertEqual(SensorCatalog.category(forKey: "Tp1C"), .cpuPerformance)
        XCTAssertEqual(SensorCatalog.category(forKey: "Te05"), .cpuEfficiency)
        XCTAssertEqual(SensorCatalog.category(forKey: "Tg0f"), .gpu)
        XCTAssertEqual(SensorCatalog.category(forKey: "TH0a"), .ssd)
        XCTAssertEqual(SensorCatalog.category(forKey: "TB0T"), .battery)
        XCTAssertEqual(SensorCatalog.category(forKey: "TPD0"), .other)
        XCTAssertNil(SensorCatalog.category(forKey: "Tf26"))
        XCTAssertNil(SensorCatalog.category(forKey: "F0Ac"))
    }

    func testImplausibleValuesAreDropped() {
        let sensors = SensorCatalog.sensors(from: [("Tp01", 6.7), ("Tp1C", 54), ("Tp1A", 40), ("Tf26", 89)])
        XCTAssertEqual(sensors.map(\.id), ["Tp1A", "Tp1C"])
        XCTAssertEqual(sensors.map(\.name), ["CPU Performance 1", "CPU Performance 2"])
    }

    func testAggregates() {
        let sensors = SensorCatalog.sensors(from: [("Tp1A", 40), ("Te05", 50), ("Tg0f", 60)])
        let snapshot = SensorSnapshot(date: .now, sensors: sensors, raw: ["Tp1A": 40, "Te05": 50, "Tg0f": 60])
        XCTAssertEqual(snapshot[Aggregate.cpuHottest.sensorID], 50)
        XCTAssertEqual(snapshot[Aggregate.cpuAverage.sensorID], 45)
        XCTAssertEqual(snapshot[Aggregate.gpuHottest.sensorID], 60)
        XCTAssertEqual(snapshot[Aggregate.hottest.sensorID], 60)
        XCTAssertNil(snapshot[Aggregate.ssdHottest.sensorID])
    }
}
