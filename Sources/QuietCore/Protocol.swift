import Foundation

public enum BoseError: LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let reason): reason }
    }
}

public struct Frame: Equatable, Sendable {
    public let group: UInt8
    public let command: UInt8
    public let operation: UInt8
    public let payload: [UInt8]

    public init(_ group: UInt8, _ command: UInt8, _ operation: UInt8, _ payload: [UInt8] = []) {
        self.group = group
        self.command = command
        self.operation = operation
        self.payload = payload
    }

    public func encoded() throws -> [UInt8] {
        guard payload.count <= 255 else { throw BoseError.invalid("Command is too long.") }
        return [group, command, operation, UInt8(payload.count)] + payload
    }
}

public struct FrameDecoder {
    private var buffer: [UInt8] = []
    public init() {}

    public mutating func append(_ bytes: [UInt8]) -> [Frame] {
        buffer.append(contentsOf: bytes)
        var frames: [Frame] = []
        while buffer.count >= 4 {
            let end = 4 + Int(buffer[3])
            guard buffer.count >= end else { break }
            frames.append(Frame(buffer[0], buffer[1], buffer[2], Array(buffer[4..<end])))
            buffer.removeFirst(end)
        }
        return frames
    }
}

public struct DeviceAddress: Hashable, Sendable, CustomStringConvertible {
    public let bytes: [UInt8]
    public init(bytes: [UInt8]) throws {
        guard bytes.count == 6 else { throw BoseError.invalid("Invalid Bluetooth address.") }
        self.bytes = bytes
    }
    public var description: String { bytes.map { String(format: "%02X", $0) }.joined(separator: ":") }
}

public struct PairedDevice: Identifiable, Equatable, Sendable {
    public let address: DeviceAddress
    public let name: String
    public let status: UInt8
    public var id: DeviceAddress { address }
    public var isConnected: Bool { status == 1 || status == 3 }
    public var isThisMac: Bool { status == 3 }
    public var statusLabel: String {
        switch status {
        case 0: "Saved"
        case 1: "Connected"
        case 3: "This Mac · Connected"
        default: "Unknown status (\(status))"
        }
    }
}

public enum BoseProtocol {
    public static let handshake = Frame(0, 1, 1)
    public static let list = Frame(4, 4, 1)
    public static let battery = Frame(2, 2, 1)
    public static let name = Frame(1, 2, 1)

    public static func addresses(_ payload: [UInt8]) throws -> [DeviceAddress] {
        guard !payload.isEmpty, (payload.count - 1).isMultiple(of: 6), payload.count <= 49 else {
            throw BoseError.invalid("The headphones returned an invalid pairing list.")
        }
        let addresses = try stride(from: 1, to: payload.count, by: 6).map {
            try DeviceAddress(bytes: Array(payload[$0..<($0 + 6)]))
        }
        guard Set(addresses).count == addresses.count else {
            throw BoseError.invalid("The headphones returned duplicate paired devices.")
        }
        return addresses
    }

    public static func device(_ payload: [UInt8], expected: DeviceAddress) throws -> PairedDevice {
        guard payload.count >= 9, Array(payload.prefix(6)) == expected.bytes,
              let name = String(bytes: payload.dropFirst(9), encoding: .utf8) else {
            throw BoseError.invalid("The headphones returned invalid device details.")
        }
        return PairedDevice(address: expected, name: name, status: payload[6])
    }

    public static func headphoneName(_ payload: [UInt8]) throws -> String {
        guard payload.first == 0, let name = String(bytes: payload.dropFirst(), encoding: .utf8) else {
            throw BoseError.invalid("The headphones returned an invalid name.")
        }
        return name
    }

    public static func rename(_ name: String) throws -> Frame {
        let bytes = Array(name.utf8)
        guard (1...31).contains(bytes.count), !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw BoseError.invalid("Use a name between 1 and 31 UTF-8 bytes, without control characters.")
        }
        return Frame(1, 2, 2, bytes)
    }

    public static func detail(_ address: DeviceAddress) -> Frame { Frame(4, 5, 1, address.bytes) }
    public static func connect(_ address: DeviceAddress) -> Frame { Frame(4, 1, 5, [0] + address.bytes) }
    public static func disconnect(_ address: DeviceAddress) -> Frame { Frame(4, 2, 5, address.bytes) }
    public static func forget(_ address: DeviceAddress) -> Frame { Frame(4, 3, 5, address.bytes) }
}
