# Quiet Control

Native macOS QC35 II management prototype in Swift 6, SwiftUI, and IOBluetooth.
Protocol parsing lives in `QuietCore`; UI and transport live in `QuietControl`.
[README.md](README.md) covers the build, protocol sources, and hardware status.

## Verify

`sh scripts/verify.sh` is the gate, locally and in CI. It needs macOS 14+ and a
Swift 6 toolchain, but no credentials or headset; `sh scripts/doctor.sh` checks
the toolchain without changing it. Build output is checkout-local, so give each
concurrent task its own checkout.

The gate proves tests and bundle validity, not UI or Bluetooth behavior. For UI
changes, launch the built app with `--demo` and exercise local alias save and
clear. Demo mode stays isolated from real aliases and hardware commands. Quit
only the app instance you launched.

## Hardware

Read commands are safe to test against connected QC35 II headphones. Confirm the
target before changing a pairing or the headphone name; other personal pairings
are real devices, not test fixtures. A mutation counts as hardware verified once
its action and read-back have both run on the headphones.

Committed artifacts omit device addresses and names. Local aliases stay separate
from names stored on the headset.
