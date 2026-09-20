import Testing
@testable import QuietCore

@Test func rejectionDoesNotRequireSuccessPayloadShape() throws {
    let address = try DeviceAddress(bytes: [1, 2, 3, 4, 5, 6])
    let expectation = ResponseExpectation(request: BoseProtocol.detail(address), operation: 3) {
        Array($0.prefix(6)) == address.bytes
    }
    let result = try #require(expectation.result(for: Frame(4, 5, 4, [5])))
    #expect(throws: DeviceRejection.self) { try result.get() }
    #expect(expectation.result(for: Frame(4, 6, 4, [5])) == nil)
    #expect(expectation.result(for: Frame(4, 5, 3, [0, 0, 0, 0, 0, 0])) == nil)
    #expect(expectation.result(for: Frame(4, 5, 7, address.bytes)) == nil)
    #expect(try expectation.result(for: Frame(4, 5, 3, address.bytes))?.get().payload == address.bytes)
}
