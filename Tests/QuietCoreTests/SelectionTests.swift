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

@Test @MainActor func demoAliasesStaySeparateFromPreferences() throws {
    let suite = "QuietControlTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let address = "10:20:30:40:50:60"
    defaults.set([address: "Private alias"], forKey: "deviceAliases")
    let model = HeadphoneModel(demo: true, defaults: defaults)
    try model.loadDemo()
    let device = try #require(model.devices.first)
    #expect(model.alias(device).isEmpty)
    model.setAlias("Preview alias", for: device)
    #expect(model.displayName(device) == "Preview alias")
    #expect(defaults.dictionary(forKey: "deviceAliases")?[address] as? String == "Private alias")
    model.setAlias("", for: device)
    #expect(model.displayName(device) == device.name)
}
