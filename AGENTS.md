# Quiet Control

Native macOS QC35 II management prototype. Use Swift 6, SwiftUI, and IOBluetooth.
Keep protocol parsing in `QuietCore` and UI/transport code in `QuietControl`.

Run `sh scripts/verify.sh` for changes; CI uses the same gate. Exercise UI changes in
the built app. Read commands can be tested against connected QC35 II headphones;
confirm the target before changing a real pairing or headphone name. Never use
unrelated personal pairings as disposable test fixtures.

Do not log device addresses or names to committed artifacts. Keep local aliases
distinct from headset-stored names. Do not claim mutation support is hardware
verified until the corresponding action and read-back have been exercised.

See [README.md](README.md) for build instructions, protocol sources, and
hardware verification limits.

Use a separate checkout per concurrent task; build output is checkout-local.
The gate needs macOS 14+ and a Swift 6 toolchain, no credentials or headset.
`sh scripts/doctor.sh` checks the selected toolchain without changing it.
CI bounds verification to ten minutes and retains step logs. Local callers must
supply their own timeout and retain output when running unattended.

For UI QA, launch `--demo` and exercise local alias save/clear. Demo mode must
not read or write real aliases or issue hardware commands. Quit only the app
instance owned by the task; do not terminate other processes by name. A passing
gate proves tests and bundle validity, not UI interaction or Bluetooth hardware.
