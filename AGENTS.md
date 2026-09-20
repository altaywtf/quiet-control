# Quiet Control

Native macOS QC35 II management prototype. Use Swift 6, SwiftUI, and IOBluetooth.
Keep protocol parsing in `QuietCore` and UI/transport code in `QuietControl`.

Run `swift test` and `sh scripts/build-app.sh` for changes. Exercise UI changes in
the built app. Read commands can be tested against connected QC35 II headphones;
confirm the target before changing a real pairing or headphone name. Never use
unrelated personal pairings as disposable test fixtures.

Do not log device addresses or names to committed artifacts. Keep local aliases
distinct from headset-stored names. Do not claim mutation support is hardware
verified until the corresponding action and read-back have been exercised.

No public remote or distribution release is configured. Protocol references and
build instructions are in README.md.
