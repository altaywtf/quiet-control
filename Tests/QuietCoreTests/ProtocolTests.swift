import Testing
@testable import QuietCore

@Test func framesSurviveEverySplitAndCoalescing() throws {
    let bytes: [UInt8] = [0, 1, 3, 5, 1, 2, 3, 4, 5, 4, 4, 3, 7, 1, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
    let expected = [Frame(0, 1, 3, [1, 2, 3, 4, 5]), Frame(4, 4, 3, [1, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])]
    for split in 0...bytes.count {
        var decoder = FrameDecoder()
        let first = decoder.append(Array(bytes.prefix(split)))
        let second = decoder.append(Array(bytes.dropFirst(split)))
        #expect(first + second == expected)
    }
    var decoder = FrameDecoder()
    #expect(bytes.flatMap { decoder.append([$0]) } == expected)
}

@Test func pairingListRejectsTruncationAndDuplicates() throws {
    #expect(try BoseProtocol.addresses([0]).isEmpty)
    #expect(throws: BoseError.self) { try BoseProtocol.addresses([]) }
    #expect(throws: BoseError.self) { try BoseProtocol.addresses([1, 2, 3]) }
    #expect(throws: BoseError.self) { try BoseProtocol.addresses([1] + Array(repeating: 0, count: 12)) }
    let addresses = try BoseProtocol.addresses([3, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
    #expect(addresses.first?.description == "AA:BB:CC:DD:EE:FF")
}

@Test func deviceDetailsValidateIdentityAndDecodeFlags() throws {
    let address = try DeviceAddress(bytes: [1, 2, 3, 4, 5, 6])
    let payload = address.bytes + [3, 0, 0] + Array("altay-mbp".utf8)
    let device = try BoseProtocol.device(payload, expected: address)
    #expect(device.isThisMac)
    #expect(device.isConnected)
    #expect(device.name == "altay-mbp")
    #expect(throws: BoseError.self) { try BoseProtocol.device(Array(payload.prefix(8)), expected: address) }
    #expect(throws: BoseError.self) {
        try BoseProtocol.device([6, 5, 4, 3, 2, 1, 0, 0, 0], expected: address)
    }
    #expect(throws: BoseError.self) { try BoseProtocol.device(address.bytes + [0, 0, 0, 0xFF], expected: address) }
    let additionalFlag = try BoseProtocol.device(address.bytes + [9, 0, 0], expected: address)
    #expect(additionalFlag.isConnected)
    #expect(!additionalFlag.isThisMac)
    let localWithFlags = try BoseProtocol.device(address.bytes + [11, 0, 0], expected: address)
    #expect(localWithFlags.isThisMac)
    let bosePeer = try BoseProtocol.device(address.bytes + [5, 0x40, 0x20, 1] + Array("Peer".utf8), expected: address)
    #expect(bosePeer.name == "Peer")
    #expect(bosePeer.isConnected)
    #expect(throws: BoseError.self) { try BoseProtocol.device(address.bytes + [4, 0, 0], expected: address) }
}

@Test func namesValidateByteLengthAndReadback() throws {
    #expect(try BoseProtocol.rename(String(repeating: "a", count: 31)).payload.count == 31)
    #expect(throws: BoseError.self) { try BoseProtocol.rename(String(repeating: "é", count: 16)) }
    #expect(throws: BoseError.self) { try BoseProtocol.rename("") }
    #expect(throws: BoseError.self) { try BoseProtocol.rename("name\n") }
    #expect(throws: BoseError.self) { try BoseProtocol.headphoneName([1, 65]) }
    #expect(try BoseProtocol.headphoneName([0] + Array("Quiet".utf8)) == "Quiet")
    #expect(throws: BoseError.self) { try Frame(0, 0, 0, Array(repeating: 0, count: 256)).encoded() }
}
