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

@Test func scanPrefersAConnectedHeadset() {
    let off = HeadphoneChoice(id: "28-11-a5-38-cc-9c", name: "QC35 II", isConnected: false)
    let on = HeadphoneChoice(id: "60-ab-d2-43-a3-17", name: "QC35 II", isConnected: true)
    #expect(HeadphoneChoice.selection(keeping: "", in: [off, on]) == on.id)
    #expect(HeadphoneChoice.selection(keeping: off.id, in: [off, on]) == on.id)
    #expect(HeadphoneChoice.selection(keeping: off.id, in: [off]) == off.id)
    #expect(HeadphoneChoice.selection(keeping: "gone", in: []) == "")
}

@Test func duplicateHeadsetNamesShowTheirAddress() {
    let labels = HeadphoneChoice.labels([
        HeadphoneChoice(id: "28-11-a5-38-cc-9c", name: "QC35 II", isConnected: false),
        HeadphoneChoice(id: "60-ab-d2-43-a3-17", name: "QC35 II", isConnected: true),
        HeadphoneChoice(id: "aa-bb-cc-dd-ee-ff", name: "Office", isConnected: true)
    ])
    #expect(labels["28-11-a5-38-cc-9c"] == "QC35 II (28:11:A5:38:CC:9C) — not connected")
    #expect(labels["60-ab-d2-43-a3-17"] == "QC35 II (60:AB:D2:43:A3:17)")
    #expect(labels["aa-bb-cc-dd-ee-ff"] == "Office")
}
