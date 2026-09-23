import Foundation

/// Four-character code helpers and value encoding for SMC keys. Numeric types are
/// big-endian except `flt `, which Apple Silicon stores little-endian.
public enum SMCCodec {
    public static func fourCC(_ string: String) -> UInt32 {
        string.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    public static func string(_ code: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
        return String(decoding: bytes, as: UTF8.self)
    }

    public static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(bytes.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        default:
            return nil
        }
    }

    public static func encode(type: String, value: Double) -> [UInt8]? {
        switch type {
        case "flt ":
            let bits = Float(value).bitPattern
            return [0, 8, 16, 24].map { UInt8((bits >> UInt32($0)) & 0xFF) }
        case "ui8 ":
            return [UInt8(clamping: Int(value.rounded()))]
        case "ui16":
            let v = UInt16(clamping: Int(value.rounded()))
            return [UInt8(v >> 8), UInt8(v & 0xFF)]
        case "fpe2":
            let v = UInt16(clamping: Int((value * 4).rounded()))
            return [UInt8(v >> 8), UInt8(v & 0xFF)]
        default:
            return nil
        }
    }
}
