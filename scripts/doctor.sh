#!/bin/sh
set -eu
if [ "$(uname -s)" != Darwin ]; then
    echo 'Runner prerequisite: macOS 14+ is required for SwiftUI and IOBluetooth.' >&2
    exit 1
fi
for tool in swift xcrun sips iconutil codesign plutil; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Runner prerequisite: missing $tool. Install Xcode or Command Line Tools and select it with xcode-select." >&2
        exit 1
    fi
done
xcrun --find swift >/dev/null
swift --version
# Package.swift owns the minimum Swift and deployment versions.
swift package dump-package >/dev/null
