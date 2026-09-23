import CoreBluetooth
import Foundation
import IOBluetooth
import QuietCore
import SwiftUI

struct HeadphoneChoice: Identifiable, Equatable {
    let id: String
    let name: String
    let isConnected: Bool
    var address: String { id.replacingOccurrences(of: "-", with: ":").uppercased() }

    static func labels(_ choices: [HeadphoneChoice]) -> [String: String] {
        let nameCounts = Dictionary(grouping: choices, by: \.name).mapValues(\.count)
        return Dictionary(choices.map { choice in
            var label = choice.name.isEmpty ? choice.address : choice.name
            if !choice.name.isEmpty, nameCounts[choice.name, default: 0] > 1 { label += " (\(choice.address))" }
            if !choice.isConnected { label += " — not connected" }
            return (choice.id, label)
        }, uniquingKeysWith: { first, _ in first })
    }

    /// Keeps the current selection unless it is gone or disconnected while another headset is connected.
    static func selection(keeping current: String, in choices: [HeadphoneChoice]) -> String {
        if let kept = choices.first(where: { $0.id == current }),
           kept.isConnected || !choices.contains(where: \.isConnected) {
            return current
        }
        return (choices.first(where: \.isConnected) ?? choices.first)?.id ?? ""
    }
}

@MainActor
final class HeadphoneModel: ObservableObject {
    @Published private(set) var choices: [HeadphoneChoice] = []
    @Published private(set) var choiceLabels: [String: String] = [:]
    @Published var selectedID = "" {
        didSet {
            guard selectedID != oldValue else { return }
            session.close()
            devices = []
            connected = false
            battery = nil
            name = "QuietComfort 35 II"
            error = nil
            message = "Read the selected headphones to load their saved devices."
        }
    }
    @Published var devices: [PairedDevice] = []
    @Published var name = "QuietComfort 35 II"
    @Published var battery: Int?
    @Published var busy = false
    @Published var connected = false
    @Published var message = "Connect your QC35 II to this Mac, then choose Read headphones."
    @Published var error: String?
    @Published private var aliases: [String: String]
    private var headphones: [String: IOBluetoothDevice] = [:]
    private let session = BluetoothSession()
    private let defaults: UserDefaults
    let demo: Bool

    init(demo: Bool = false, defaults: UserDefaults = .standard) {
        self.demo = demo
        self.defaults = defaults
        aliases = demo ? [:] : (defaults.dictionary(forKey: "deviceAliases") as? [String: String] ?? [:])
        session.onClose = { [weak self] in
            self?.connected = false
            self?.devices = []
            self?.message = "Disconnected. Connect the headphones and read them again."
        }
    }

    func scan() {
        guard !demo else { return }
        if [.denied, .restricted].contains(CBManager.authorization) {
            error = "Bluetooth access is off for Quiet Control. Allow it in System Settings → Privacy & Security → Bluetooth."
        }
        let devices = BluetoothSession.pairedHeadphones()
        headphones = Dictionary(devices.compactMap { device in
            device.addressString.map { ($0, device) }
        }, uniquingKeysWith: { first, _ in first })
        choices = devices.compactMap { device in
            guard let id = device.addressString else { return nil }
            return HeadphoneChoice(id: id, name: device.name ?? "", isConnected: device.isConnected())
        }
        choiceLabels = HeadphoneChoice.labels(choices)
        selectedID = HeadphoneChoice.selection(keeping: selectedID, in: choices)
    }

    func read() {
        run {
            self.devices = []
            self.battery = nil
            self.connected = false
            guard let target = self.headphones[self.selectedID] else {
                throw BoseError.invalid("No QC35 II found. Pair it in System Settings → Bluetooth, then scan again.")
            }
            self.message = "Reading headphones…"
            try await self.session.open(target)
            try await self.refresh()
            self.connected = true
            self.message = "Saved devices read from the headphones."
        }
    }

    private func refresh() async throws {
        let list = try await session.exchange(BoseProtocol.list, responseOperation: 3)
        let addresses = try BoseProtocol.addresses(list.payload)
        var loaded: [PairedDevice] = []
        for address in addresses {
            let detail = try await session.exchange(BoseProtocol.detail(address), responseOperation: 3) {
                Array($0.prefix(6)) == address.bytes
            }
            loaded.append(try BoseProtocol.device(detail.payload, expected: address))
        }
        devices = loaded
        let response = try await session.exchange(BoseProtocol.name, responseOperation: 3)
        name = try BoseProtocol.headphoneName(response.payload)
        let power = try await session.exchange(BoseProtocol.battery, responseOperation: 3)
        battery = power.payload.first.flatMap { $0 <= 100 ? Int($0) : nil }
    }

    func rename(_ proposed: String) {
        run {
            let command = try BoseProtocol.rename(proposed)
            let response = try await self.session.exchange(command, responseOperation: 3)
            let readback = try BoseProtocol.headphoneName(response.payload)
            guard readback == proposed else { throw BoseError.invalid("The headphones did not accept that name.") }
            self.name = readback
            self.message = "Headphone name updated."
        }
    }

    func changeConnection(_ device: PairedDevice) {
        guard !device.isThisMac else { return }
        run {
            let command = device.isConnected ? BoseProtocol.disconnect(device.address) : BoseProtocol.connect(device.address)
            _ = try await self.session.exchange(command, responseOperation: 6) { $0 == device.address.bytes }
            try await self.refresh()
            guard let updated = self.devices.first(where: { $0.id == device.id }), updated.isConnected != device.isConnected else {
                throw BoseError.invalid("The request was accepted, but the connection has not changed. Check the other device and refresh.")
            }
            self.message = "Connection updated."
        }
    }

    func forget(_ device: PairedDevice) {
        guard !device.isThisMac else { return }
        run {
            _ = try await self.session.exchange(BoseProtocol.forget(device.address), responseOperation: 6) { $0 == device.address.bytes }
            try await self.refresh()
            guard !self.devices.contains(where: { $0.id == device.id }) else {
                throw BoseError.invalid("The device is still in the pairing list. Refresh before trying again.")
            }
            self.message = "Device removed from the headphones."
        }
    }

    func displayName(_ device: PairedDevice) -> String {
        alias(device).isEmpty ? (device.name.isEmpty ? device.address.description : device.name) : alias(device)
    }

    func alias(_ device: PairedDevice) -> String { aliases[device.address.description] ?? "" }

    func setAlias(_ name: String, for device: PairedDevice) {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        aliases[device.address.description] = value.isEmpty ? nil : value
        if !demo { defaults.set(aliases, forKey: "deviceAliases") }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy, !demo else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do { try await action() }
            catch is CancellationError {}
            catch {
                self.error = error.localizedDescription
                connected = session.isOpen
                if !connected { devices = []; battery = nil }
                message = connected ? "Refresh to read the current headphone state." : "Connect and read the headphones again."
            }
        }
    }

    func loadDemo() throws {
        devices = try [
            ([0x10, 0x20, 0x30, 0x40, 0x50, 0x60], "MacBook Pro", 3),
            ([0x20, 0x30, 0x40, 0x50, 0x60, 0x70], "iPhone", 1),
            ([0x30, 0x40, 0x50, 0x60, 0x70, 0x80], "Old laptop", 0)
        ].map { bytes, name, status in
            let address = try DeviceAddress(bytes: bytes.map(UInt8.init))
            return try BoseProtocol.device(address.bytes + [UInt8(status), 0, 0] + Array(name.utf8), expected: address)
        }
        battery = 80
        message = "Preview with sample devices. Headphone commands are disabled."
    }
}
