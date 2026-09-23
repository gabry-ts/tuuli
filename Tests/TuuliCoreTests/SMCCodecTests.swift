import XCTest
@testable import TuuliCore

final class SMCCodecTests: XCTestCase {
    func testFourCCRoundTrip() {
        XCTAssertEqual(SMCCodec.string(SMCCodec.fourCC("F0Tg")), "F0Tg")
        XCTAssertEqual(SMCCodec.fourCC("#KEY"), 0x234B_4559)
    }

    func testFloatIsLittleEndian() {
        let bytes = SMCCodec.encode(type: "flt ", value: 2317)!
        XCTAssertEqual(bytes, [0x00, 0xD0, 0x10, 0x45])
        XCTAssertEqual(SMCCodec.decode(type: "flt ", bytes: bytes), 2317)
    }

    func testBigEndianIntegers() {
        XCTAssertEqual(SMCCodec.decode(type: "ui16", bytes: [0x01, 0x02]), 258)
        XCTAssertEqual(SMCCodec.decode(type: "ui32", bytes: [0, 0, 0x81, 0]), 33024)
        XCTAssertEqual(SMCCodec.encode(type: "ui8 ", value: 1), [1])
    }

    func testFixedPoint() {
        XCTAssertEqual(SMCCodec.decode(type: "sp78", bytes: [0x2A, 0x80]), 42.5)
        XCTAssertEqual(SMCCodec.decode(type: "fpe2", bytes: [0x1F, 0x40]), 2000)
        XCTAssertEqual(SMCCodec.encode(type: "fpe2", value: 2000), [0x1F, 0x40])
    }

    func testUnknownTypeIsNil() {
        XCTAssertNil(SMCCodec.decode(type: "ioft", bytes: [1, 2, 3, 4]))
    }
}
