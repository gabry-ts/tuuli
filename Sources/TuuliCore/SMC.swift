import Foundation
import IOKit

public enum SMCError: Error, CustomStringConvertible {
    case serviceNotFound
    case openFailed(kern_return_t)
    case keyNotFound(String)
    case unsupportedType(String)
    case callFailed(String, kern_return_t, UInt8)

    public var description: String {
        switch self {
        case .serviceNotFound: "AppleSMC service not found"
        case .openFailed(let code): "Could not open AppleSMC (\(code))"
        case .keyNotFound(let key): "SMC key \(key) not found"
        case .unsupportedType(let type): "Unsupported SMC type \(type)"
        case .callFailed(let key, let code, let result): "SMC call for \(key) failed (\(code), result \(result))"
        }
    }
}

public struct SMCKeyInfo: Sendable, Equatable {
    public let size: Int
    public let type: String
}

/// Direct access to the AppleSMC user client. Reading works for any user; writing fan
/// keys requires root, which is why writes happen only inside the privileged helper.
public final class SMC: @unchecked Sendable {
    private var connection: io_connect_t = 0
    private let lock = NSLock()
    private var infoCache: [UInt32: SMCKeyInfo] = [:]

    // Layout of the kernel's 80-byte SMCKeyData_t.
    private enum Offset {
        static let key = 0
        static let dataSize = 28
        static let dataType = 32
        static let result = 40
        static let command = 42
        static let data32 = 44
        static let bytes = 48
    }

    private enum Command: UInt8 {
        case readBytes = 5
        case writeBytes = 6
        case keyAtIndex = 8
        case keyInfo = 9
    }

    public init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.serviceNotFound }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else { throw SMCError.openFailed(result) }
    }

    deinit {
        IOServiceClose(connection)
    }

    public func info(_ key: String) -> SMCKeyInfo? {
        lock.withLock { info(code: SMCCodec.fourCC(key)) }
    }

    public func readBytes(_ key: String) -> (type: String, bytes: [UInt8])? {
        lock.withLock {
            let code = SMCCodec.fourCC(key)
            guard let info = info(code: code) else { return nil }
            var input = request(code, .readBytes)
            store(UInt32(info.size), at: Offset.dataSize, in: &input)
            guard let output = try? call(input, key: key) else { return nil }
            return (info.type, Array(output[Offset.bytes..<Offset.bytes + min(info.size, 32)]))
        }
    }

    public func read(_ key: String) -> Double? {
        guard let raw = readBytes(key) else { return nil }
        return SMCCodec.decode(type: raw.type, bytes: raw.bytes)
    }

    public func write(_ key: String, bytes: [UInt8]) throws {
        try lock.withLock {
            let code = SMCCodec.fourCC(key)
            guard let info = info(code: code) else { throw SMCError.keyNotFound(key) }
            var input = request(code, .writeBytes)
            store(UInt32(info.size), at: Offset.dataSize, in: &input)
            for (i, byte) in bytes.prefix(info.size).enumerated() {
                input[Offset.bytes + i] = byte
            }
            _ = try call(input, key: key)
        }
    }

    public func write(_ key: String, value: Double) throws {
        guard let info = info(key) else { throw SMCError.keyNotFound(key) }
        guard let bytes = SMCCodec.encode(type: info.type, value: value) else {
            throw SMCError.unsupportedType(info.type)
        }
        try write(key, bytes: bytes)
    }

    /// Every key the SMC exposes, in index order.
    public func allKeys() -> [String] {
        guard let count = read("#KEY"), count > 0 else { return [] }
        return lock.withLock {
            (0..<UInt32(count)).compactMap { index in
                var input = request(0, .keyAtIndex)
                store(index, at: Offset.data32, in: &input)
                guard let output = try? call(input, key: "#\(index)") else { return nil }
                return SMCCodec.string(load(at: Offset.key, in: output))
            }
        }
    }

    // MARK: Private

    private func info(code: UInt32) -> SMCKeyInfo? {
        if let cached = infoCache[code] { return cached }
        let input = request(code, .keyInfo)
        guard let output = try? call(input, key: SMCCodec.string(code)) else { return nil }
        let info = SMCKeyInfo(
            size: Int(load(at: Offset.dataSize, in: output)),
            type: SMCCodec.string(load(at: Offset.dataType, in: output))
        )
        infoCache[code] = info
        return info
    }

    private func request(_ key: UInt32, _ command: Command) -> [UInt8] {
        var input = [UInt8](repeating: 0, count: 80)
        store(key, at: Offset.key, in: &input)
        input[Offset.command] = command.rawValue
        return input
    }

    private func call(_ input: [UInt8], key: String) throws -> [UInt8] {
        var input = input
        var output = [UInt8](repeating: 0, count: 80)
        var outputSize = output.count
        let code = IOConnectCallStructMethod(connection, 2, &input, input.count, &output, &outputSize)
        guard code == kIOReturnSuccess, output[Offset.result] == 0 else {
            throw SMCError.callFailed(key, code, output[Offset.result])
        }
        return output
    }

    /// Struct fields are native-endian (little-endian on Apple Silicon).
    private func store(_ value: UInt32, at offset: Int, in buffer: inout [UInt8]) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            for i in 0..<4 { buffer[offset + i] = bytes[i] }
        }
    }

    private func load(at offset: Int, in buffer: [UInt8]) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(buffer[offset + $1]) << (8 * UInt32($1)) }
    }
}
