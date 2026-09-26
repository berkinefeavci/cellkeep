import Foundation
import IOKit

/// Read-only AppleSMC access. There is deliberately no write command or helper connection.
/// ABI reference: https://github.com/hholtmann/smcFanControl/blob/master/smc-command/smc.h
/// AppleSMCKeysEndpoint on this macOS 27 Mac still accepts the classic 80-byte message.
final class SMCReader {
    static let shared = SMCReader()

    struct ComponentPower: Equatable {
        let key: String
        let watts: Double
    }

    struct ComponentPowers: Equatable {
        let system: ComponentPower?
        let processor: ComponentPower?
        let display: ComponentPower?
    }

    struct Value {
        let key: String
        let type: String
        let bytes: [UInt8]

        var number: Double? {
            switch (type, bytes.count) {
            case ("sp78", 2):
                let bits = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
                return Double(Int16(bitPattern: bits)) / 256
            case ("flt ", 4):
                let bits = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
                let value = Double(Float(bitPattern: bits))
                return value.isFinite ? value : nil
            case ("ui8 ", 1):
                return Double(bytes[0])
            case ("ui32", 4) where key == "#KEY":
                return unsignedInteger(littleEndian: false).map { Double($0) }
            default:
                return nil
            }
        }

        // Integer byte order is key/firmware-dependent: #KEY is big-endian,
        // while observed macOS 27 battery ui16/ui32 values are little-endian.
        // Require callers to select an order instead of silently misreading control bytes.
        func unsignedInteger(littleEndian: Bool) -> UInt64? {
            guard (1...8).contains(bytes.count) else { return nil }
            let ordered = littleEndian ? Array(bytes.reversed()) : bytes
            return ordered.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        }
    }

    enum ReadError: Error, CustomStringConvertible {
        case invalidKey
        case unavailable
        case transport(kern_return_t)
        case keyNotFound(String)
        case smc(String, UInt8)
        case malformedResponse

        var description: String {
            switch self {
            case .invalidKey: return "SMC key must contain exactly four ASCII bytes"
            case .unavailable: return "AppleSMC service unavailable"
            case .transport(let code): return String(format: "SMC transport error 0x%08x", code)
            case .keyNotFound(let key): return "SMC key \(key) unavailable (0x84)"
            case .smc(let key, let code): return String(format: "SMC key %@ error 0x%02x", key, code)
            case .malformedResponse: return "Invalid SMC response layout or data size"
            }
        }
    }

    private var connection: io_connect_t = 0
    private var keyInfo: [String: (size: Int, type: String)] = [:]
    private let lock = NSLock()

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    func read(_ key: String) throws -> Value {
        let characters = Array(key.utf8)
        guard characters.count == 4, characters.allSatisfy({ $0 < 128 }) else { throw ReadError.invalidKey }
        lock.lock()
        defer { lock.unlock() }
        try openIfNeeded()
        let keyCode = characters.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }

        if keyInfo[key] == nil {
            let response = try call(key: key, code: keyCode, command: .keyInfo)
            let size = Int(Self.littleEndianUInt32(response, at: 28))
            guard (1...32).contains(size) else { throw ReadError.malformedResponse }
            let type = String(bytes: response[32..<36].reversed(), encoding: .ascii)
            guard let type else { throw ReadError.malformedResponse }
            keyInfo[key] = (size, type)
        }
        guard let info = keyInfo[key] else { throw ReadError.malformedResponse }
        let response = try call(key: key, code: keyCode, command: .bytes, size: info.size)
        return Value(key: key, type: info.type, bytes: Array(response[48..<(48 + info.size)]))
    }

    func batteryTemperature() -> Value? {
        guard let value = try? read("TB1T"), ["flt ", "sp78"].contains(value.type),
              let temperature = value.number, (-40...100).contains(temperature) else { return nil }
        return value
    }

    static func componentPowers(read: (String) -> Double?) -> ComponentPowers {
        func first(_ keys: [String], range: ClosedRange<Double>) -> ComponentPower? {
            for key in keys {
                guard let watts = read(key), watts.isFinite, range.contains(watts) else { continue }
                return ComponentPower(key: key, watts: watts)
            }
            return nil
        }
        return ComponentPowers(
            system: first(["PSTR"], range: 0...300),
            processor: first(["PZC0", "PCPR", "PCTR", "PCPT", "PCPC", "PC0C"], range: 0...250),
            display: first(["PDBR", "PBwo"], range: 0...100)
        )
    }

    func componentPowers() -> ComponentPowers {
        Self.componentPowers { try? self.read($0).number }
    }

    private func openIfNeeded() throws {
        guard connection == 0 else { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw ReadError.unavailable }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            connection = 0
            throw ReadError.transport(result)
        }
    }

    private enum ReadCommand: UInt8 { case bytes = 5, keyInfo = 9 }

    private func call(key: String, code: UInt32, command: ReadCommand, size: Int = 0) throws -> [UInt8] {
        // Explicit offsets preserve C padding; native Swift nested structs may reuse tail padding.
        // key=0, keyInfo.size=28, keyInfo.type=32, result=40, status=41, command=42,
        // data32=44, payload=48. Selector 2 is the dispatcher, not the read command.
        var input = [UInt8](repeating: 0, count: 80)
        var output = [UInt8](repeating: 0, count: 80)
        for index in 0..<4 { input[index] = UInt8(truncatingIfNeeded: code >> (index * 8)) }
        input[28] = UInt8(size)
        input[42] = command.rawValue
        var outputSize = output.count
        let result = input.withUnsafeBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                IOConnectCallStructMethod(connection, 2, inputBytes.baseAddress, inputBytes.count,
                                          outputBytes.baseAddress, &outputSize)
            }
        }
        guard result == kIOReturnSuccess else {
            IOServiceClose(connection)
            connection = 0
            keyInfo.removeAll()
            throw ReadError.transport(result)
        }
        guard outputSize == 80 else { throw ReadError.malformedResponse }
        if output[40] == 0x84 { throw ReadError.keyNotFound(key) }
        guard output[40] == 0 else { throw ReadError.smc(key, output[40]) }
        return output
    }

    private static func littleEndianUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
    }
}
