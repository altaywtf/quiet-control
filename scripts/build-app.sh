#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app='dist/Quiet Control.app'
mkdir -p "$app/Contents/MacOS"
cp .build/release/QuietControl "$app/Contents/MacOS/QuietControl"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
printf '%s\n' "$app"
