import Foundation
import Testing
@testable import QuietControl

@Test @MainActor func switchingHeadphonesInvalidatesLoadedState() throws {
    let model = HeadphoneModel(demo: true)
    try model.loadDemo()
    model.connected = true
    model.name = "First headphones"
    model.error = "Previous error"

    model.selectedID = "Another headphone"

    #expect(model.devices.isEmpty)
    #expect(!model.connected)
    #expect(model.battery == nil)
    #expect(model.error == nil)
    #expect(model.name != "First headphones")
}
