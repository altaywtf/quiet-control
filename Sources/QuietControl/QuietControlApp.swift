import AppKit
import SwiftUI
import QuietCore

@main
struct QuietControlApp: App {
    @StateObject private var model = HeadphoneModel(demo: CommandLine.arguments.contains("--demo"))

    var body: some Scene {
        Window("Quiet Control", id: "main") {
            HeadphoneView(model: model)
                .task {
                    if CommandLine.arguments.contains("--inspect-protocol") {
                        let success = await ProtocolInspection.run()
                        exit(success ? 0 : 1)
                    }
                    if model.demo { try? model.loadDemo() }
                    else { model.scan() }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 640, height: 540)
        MenuBarExtra("Quiet Control", systemImage: "headphones") {
            OpenWindowButton()
            Divider()
            Button("Quit Quiet Control") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

private struct OpenWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Manage headphones…") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

private enum Editor: Identifiable {
    case headphones
    case alias(PairedDevice)
    var id: String {
        switch self { case .headphones: "headphones"; case .alias(let device): device.address.description }
    }
}

private struct HeadphoneView: View {
    @ObservedObject var model: HeadphoneModel
    @State private var editor: Editor?
    @State private var forgetDevice: PairedDevice?
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.name).font(.title2.weight(.semibold)).textSelection(.enabled)
                    Text(model.demo ? "Preview" : (model.connected ? "Headphones connected" : "QC35 II device manager"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let battery = model.battery {
                    Label("\(battery)%", systemImage: "battery.75percent")
                        .accessibilityLabel("Battery \(battery) percent")
                }
                Button("Rename…") { draft = model.name; editor = .headphones }
                    .disabled(!model.connected || model.busy || model.demo)
            }

            if !model.demo {
                HStack {
                    Picker("Headphones", selection: $model.selectedID) {
                        if model.headphones.isEmpty { Text("No QC35 found").tag("") }
                        ForEach(model.headphones, id: \.addressString) { headphone in
                            Text(headphone.nameOrAddress ?? "Headphones").tag(headphone.addressString ?? "")
                        }
                    }
                    .disabled(model.busy)
                    Button("Scan") { model.scan() }.disabled(model.busy)
                    Button(model.connected ? "Refresh" : "Read headphones") { model.read() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.busy || model.selectedID.isEmpty)
                        .keyboardShortcut("r")
                }
            }

            Divider()
            HStack {
                Text("Saved devices").font(.headline)
                Spacer()
                Text("\(model.devices.count) of 8").foregroundStyle(.secondary)
            }

            if model.devices.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "headphones").font(.largeTitle).foregroundStyle(.secondary)
                    Text(model.busy ? "Reading saved devices…" : "Your pairing list will appear here.")
                    Text("Read the headphones to see the phones and computers they remember.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.devices) { device in
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(model.displayName(device)).fontWeight(.medium).textSelection(.enabled)
                                    Text(device.statusLabel).foregroundStyle(.secondary)
                                    if !model.alias(device).isEmpty {
                                        Text("Reported name: \(device.name)").foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if !device.isThisMac {
                                    Button(device.isConnected ? "Disconnect" : "Connect") { model.changeConnection(device) }
                                        .disabled(model.busy || !model.connected || model.demo)
                                }
                                Menu {
                                    Button("Edit local alias…") {
                                        draft = model.alias(device)
                                        editor = .alias(device)
                                    }
                                    Button("Forget device…", role: .destructive) { forgetDevice = device }
                                        .disabled(device.isThisMac || model.busy || !model.connected || model.demo)
                                } label: { Image(systemName: "ellipsis") }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .accessibilityLabel("Actions for \(model.displayName(device))")
                            }
                            .padding(.vertical, 14)
                            Divider()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.message).foregroundStyle(.secondary)
                }
                Text("Aliases are saved on this Mac. They don’t change device names announced by the headphones.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(24)
        .frame(minWidth: 580, minHeight: 440)
        .sheet(item: $editor) { item in
            VStack(alignment: .leading, spacing: 16) {
                Text(editorTitle(item)).font(.headline)
                TextField("Name", text: $draft).textFieldStyle(.roundedBorder)
                    .onSubmit { saveEditor(item) }
                Text(editorHelp(item)).foregroundStyle(.secondary).font(.callout)
                HStack {
                    Spacer()
                    Button("Cancel") { editor = nil }.keyboardShortcut(.cancelAction)
                    Button("Save") { saveEditor(item) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!validDraft(item))
                }
            }.padding(24).frame(width: 380)
        }
        .alert("Forget \(forgetDevice.map(model.displayName) ?? "device")?", isPresented: Binding(
            get: { forgetDevice != nil }, set: { if !$0 { forgetDevice = nil } }
        ), presenting: forgetDevice) { device in
            Button("Cancel", role: .cancel) { forgetDevice = nil }
            Button("Forget device", role: .destructive) { model.forget(device); forgetDevice = nil }
        } message: { _ in
            Text("This removes the pairing from the headphones. You’ll need to pair that device again to use it.")
        }
    }

    private func editorTitle(_ editor: Editor) -> String {
        switch editor { case .headphones: "Rename headphones"; case .alias: "Local device alias" }
    }
    private func editorHelp(_ editor: Editor) -> String {
        switch editor {
        case .headphones: "Changes the name stored on the headphones. Up to 31 UTF-8 bytes."
        case .alias: "Shown only in Quiet Control on this Mac. Leave empty to use the reported name."
        }
    }
    private func validDraft(_ editor: Editor) -> Bool {
        switch editor { case .headphones: (try? BoseProtocol.rename(draft)) != nil; case .alias: true }
    }
    private func saveEditor(_ item: Editor) {
        guard validDraft(item) else { return }
        switch item { case .headphones: model.rename(draft); case .alias(let device): model.setAlias(draft, for: device) }
        editor = nil
    }
}
