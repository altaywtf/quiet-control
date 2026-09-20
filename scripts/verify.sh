#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/doctor.sh
swift test
sh scripts/build-app.sh
plutil -lint 'dist/Quiet Control.app/Contents/Info.plist'
codesign --verify --strict 'dist/Quiet Control.app'
test -s 'dist/Quiet Control.app/Contents/Resources/AppIcon.icns'
git diff --check
