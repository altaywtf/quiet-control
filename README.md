<img src="Resources/AppIcon.png" width="96" alt="Quiet Control icon">

# Quiet Control

A macOS app for managing devices paired with Bose QC35 II headphones.

![Saved devices](docs/screenshots/saved-devices.png)

Read saved devices, connection status, and battery level. Connect, disconnect,
or forget other devices, rename the headphones, and set local device aliases.
The controlling Mac is protected from disconnect and forget actions.

**Aliases stay on this Mac.** They do not change names stored or announced by
the headphones. See the [peer-name investigation](docs/peer-name-protocol.md).

Reads, headphone rename, and forget are tested on hardware. Connect and
disconnect still need hardware verification. Refresh after an uncertain result before
sending another command.

## Build and run

Requires macOS 14+ and Swift 6 (Xcode or Command Line Tools).

```sh
git clone https://github.com/altaywtf/quiet-control.git
cd quiet-control
sh scripts/verify.sh
open 'dist/Quiet Control.app'
```

Connect the headphones in System Settings → Bluetooth, then select them in
Quiet Control and choose **Read headphones**. Allow Bluetooth access if asked.
Use **Refresh** to read changes.

The app is signed ad hoc, not notarized. No third-party packages or telemetry.

## Preview and diagnostics

Quit the app before using either launch option:

```sh
open 'dist/Quiet Control.app' --args --demo
'dist/Quiet Control.app/Contents/MacOS/QuietControl' --inspect-protocol
```

Demo mode uses sample devices, keeps aliases in memory, and disables headphone
commands. The screenshots show this mode.

![Local alias editor](docs/screenshots/local-alias.png)

Protocol inspection requires exactly one Bose headphone connected. It sends
read-only queries and omits device names, addresses, and serial numbers.
See the [findings and packet definitions](docs/peer-name-protocol.md).

## Credits

- [based-connect](https://github.com/Denton-L/based-connect/blob/ef66145bf4739ec96c1a6959f63146d12ba87e4c/based.c)
  (GPL-3.0): wire-protocol reference. Quiet Control implements the messages independently.
- [bose-macos-utility](https://github.com/lukasz-zet/bose-macos-utility/blob/a4c919f0cfce739f7408d1def190171218df0a6f/bose-macos-utility/bose-macos-utility/AppDelegate.swift)
  (MIT): macOS RFCOMM service discovery.
- [Research sources](docs/peer-name-protocol.md#sources): iclemens/bose,
  aaronsb/bosectl, and Bose Connect packet definitions. No APK or decompiled
  source is included.

[MIT licensed](LICENSE). Unaffiliated with Bose.
