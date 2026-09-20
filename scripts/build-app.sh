#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app='dist/Quiet Control.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
iconset='dist/AppIcon.iconset'
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp .build/release/QuietControl "$app/Contents/MacOS/QuietControl"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
printf '%s\n' "$app"
