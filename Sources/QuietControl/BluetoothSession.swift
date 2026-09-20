import Foundation
import IOBluetooth
import QuietCore

@MainActor
final class BluetoothSession: NSObject, @preconcurrency IOBluetoothRFCOMMChannelDelegate {
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var decoder = FrameDecoder()
    private var connection: CheckedContinuation<Void, Error>?
    private var request: CheckedContinuation<Frame, Error>?
    private var expectation: ResponseExpectation?
    private var timeout: Task<Void, Never>?
    private var writes: [UInt: NSMutableData] = [:]
    private var writeID: UInt = 0
    var onClose: (() -> Void)?
    var onFrame: ((Frame) -> Void)?
    var isOpen: Bool { channel?.isOpen() == true }

    static func pairedHeadphones() -> [IOBluetoothDevice] {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.filter {
            let name = ($0.name ?? "").lowercased()
            let services = $0.services as? [IOBluetoothSDPServiceRecord] ?? []
            return name.contains("bose") || name.contains("quietcomfort") || name.contains("qc35")
                || services.contains { $0.getServiceName() == "SPP Dev" }
        }
    }

    func open(_ target: IOBluetoothDevice) async throws {
        close()
        device = target
        try await withCheckedThrowingContinuation { continuation in
            connection = continuation
            armTimeout("Bluetooth connection timed out. Connect the headphones in System Settings, then retry.", seconds: 15)
            let status = target.performSDPQuery(self)
            if status != kIOReturnSuccess { fail(ioError("Discovering headphone services", status)) }
        }
        _ = try await exchange(BoseProtocol.handshake, responseOperation: 3)
    }

    @objc func sdpQueryComplete(_ queriedDevice: IOBluetoothDevice, status: IOReturn) {
        guard queriedDevice == device, connection != nil else { return }
        guard status == kIOReturnSuccess else { fail(ioError("Discovering headphone services", status)); return }
        let services = queriedDevice.services as? [IOBluetoothSDPServiceRecord] ?? []
        guard let service = services.first(where: { $0.getServiceName() == "SPP Dev" }) else {
            fail(BoseError.invalid("This device does not expose the QC35 control service (SPP Dev)."))
            return
        }
        var channelID: BluetoothRFCOMMChannelID = 0
        let result = service.getRFCOMMChannelID(&channelID)
        guard result == kIOReturnSuccess, channelID != 0 else {
            fail(ioError("Finding the control channel", result)); return
        }
        let opening = queriedDevice.openRFCOMMChannelAsync(&channel, withChannelID: channelID, delegate: self)
        if opening != kIOReturnSuccess { fail(ioError("Opening the control channel", opening)) }
    }

    func rfcommChannelOpenComplete(_ opened: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        guard connection != nil else { _ = opened?.close(); return }
        guard status == kIOReturnSuccess else { fail(ioError("Opening the control channel", status)); return }
        channel = opened
        timeout?.cancel()
        let pending = connection
        connection = nil
        pending?.resume()
    }

    func exchange(_ frame: Frame, responseOperation: UInt8,
                  payloadMatches: @escaping (Array<UInt8>) -> Bool = { _ in true }) async throws -> Frame {
        guard let channel, channel.isOpen() else { throw BoseError.invalid("The headphones are disconnected.") }
        guard request == nil else { throw BoseError.invalid("Another headphone command is still running.") }
        try Task.checkCancellation()
        let bytes = try frame.encoded()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request = continuation
                expectation = ResponseExpectation(request: frame, operation: responseOperation, payloadMatches: payloadMatches)
                armTimeout("The headphones did not confirm the command. Reconnect and refresh before trying again.", seconds: 6)
                let data = NSMutableData(bytes: bytes, length: bytes.count)
                writeID += 1
                let id = writeID
                writes[id] = data
                let status = channel.writeAsync(data.mutableBytes, length: UInt16(data.length), refcon: UnsafeMutableRawPointer(bitPattern: id))
                if status != kIOReturnSuccess {
                    writes.removeValue(forKey: id)
                    fail(ioError("Sending the command", status))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.fail(CancellationError()) }
        }
    }

    func rfcommChannelWriteComplete(_ channel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status: IOReturn) {
        if let refcon { writes.removeValue(forKey: UInt(bitPattern: refcon)) }
        if status != kIOReturnSuccess { fail(ioError("Sending the command", status)) }
    }

    func rfcommChannelData(_ incoming: IOBluetoothRFCOMMChannel!, data pointer: UnsafeMutableRawPointer!, length: Int) {
        guard incoming == channel, let pointer, length > 0 else { return }
        let bytes = Array(UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: UInt8.self), count: length))
        for frame in decoder.append(bytes) {
            onFrame?(frame)
            guard let result = expectation?.result(for: frame) else { continue }
            timeout?.cancel()
            let pending = request
            request = nil
            expectation = nil
            switch result {
            case .success(let response): pending?.resume(returning: response)
            case .failure(let error): pending?.resume(throwing: error)
            }
        }
    }

    func rfcommChannelClosed(_ closed: IOBluetoothRFCOMMChannel!) {
        guard closed == channel else { return }
        fail(BoseError.invalid("The headphones disconnected. Connect them and refresh."))
        onClose?()
    }

    func close() { fail(CancellationError()) }

    private func fail(_ error: Error) {
        timeout?.cancel()
        timeout = nil
        let opening = connection
        let pending = request
        connection = nil
        request = nil
        expectation = nil
        let closing = channel
        channel = nil
        closing?.setDelegate(nil)
        _ = closing?.close()
        writes.removeAll()
        device = nil
        decoder = FrameDecoder()
        opening?.resume(throwing: error)
        pending?.resume(throwing: error)
    }

    private func armTimeout(_ message: String, seconds: UInt64) {
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: seconds * 1_000_000_000) }
            catch { return }
            self?.fail(BoseError.invalid(message))
        }
    }

    private func ioError(_ action: String, _ status: IOReturn) -> Error {
        BoseError.invalid("\(action) failed (\(status)). Check Bluetooth permission in System Settings → Privacy & Security → Bluetooth.")
    }
}
