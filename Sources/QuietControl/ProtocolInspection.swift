import Foundation
import IOBluetooth
import QuietCore

@MainActor
enum ProtocolInspection {
    static func run() async -> Bool {
        let candidates = BluetoothSession.pairedHeadphones().filter { $0.isConnected() }
        guard candidates.count == 1, let target = candidates.first else {
            print("Inspection requires exactly one connected Bose headphone candidate.")
            return false
        }
        let session = BluetoothSession()
        defer { session.close() }
        do {
            try await session.open(target)
            let identity = try await session.exchange(Frame(0, 3, 1), responseOperation: 3)
            guard identity.payload.count == 3, identity.payload.prefix(2) == [0x40, 0x20] else {
                print("Inspection stopped: connected device is not a QC35 II (0x4020).")
                return false
            }
            let queries: [(String, Frame)] = [
                ("Firmware", Frame(0, 5, 1)),
                ("Function blocks", Frame(0, 2, 1)),
                ("Device-management block info", Frame(4, 0, 1))
            ]
            for (label, query) in queries {
                do {
                    let reply = try await session.exchange(query, responseOperation: 3)
                    print("\(label): \(hex(try query.encoded())) -> \(hex(try reply.encoded()))")
                } catch let error as DeviceRejection {
                    print("\(label): \(error.localizedDescription)")
                }
            }

            var discoveredHeaders = Set<String>()
            session.onFrame = { frame in
                discoveredHeaders.insert("\(frame.group).\(frame.command) op=\(frame.operation) bytes=\(frame.payload.count)")
                if frame.group == 0 && frame.command == 4 {
                    print("Function discovery: \(hex((try? frame.encoded()) ?? []))")
                }
            }
            do {
                _ = try await session.exchange(Frame(0, 4, 5), responseOperation: 6)
            } catch let error as DeviceRejection {
                print("Function discovery: \(error.localizedDescription)")
            }
            session.onFrame = nil
            print("Discovery response headers (payloads omitted):")
            for header in discoveredHeaders.sorted() { print("  \(header)") }

            let list = try await session.exchange(BoseProtocol.list, responseOperation: 3)
            let addresses = try BoseProtocol.addresses(list.payload)
            print("Saved peers: \(addresses.count); addresses and names omitted.")
            for address in addresses {
                let reply = try await session.exchange(BoseProtocol.detail(address), responseOperation: 3) {
                    Array($0.prefix(6)) == address.bytes
                }
                let peer = try BoseProtocol.device(reply.payload, expected: address)
                guard peer.isThisMac else { continue }
                print("Current-host info: status \(peer.status), name length \(peer.name.utf8.count) bytes.")
                do {
                    let extended = try await session.exchange(Frame(4, 6, 1, address.bytes), responseOperation: 3)
                    let hasAddress = extended.payload.starts(with: address.bytes)
                    print("Current-host extended info: \(extended.payload.count) bytes; address prefix=\(hasAddress), equals peer name=\(extended.payload == Array(peer.name.utf8)).")
                    if hasAddress, extended.payload.count == 8 {
                        print("Extended info trailing fields: \(hex(Array(extended.payload.suffix(2)))) (meaning unknown).")
                    }
                } catch let error as DeviceRejection {
                    print("Current-host extended info: \(error.localizedDescription)")
                }
            }
            print("Inspection complete. Only metadata discovery and GET requests were sent.")
            return true
        } catch {
            print("Inspection stopped: \(error.localizedDescription)")
            return false
        }
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
