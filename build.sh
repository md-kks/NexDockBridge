#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="$PWD/build/NexDockBridge.app"
mkdir -p "$app/Contents/MacOS"
cp src/Info.plist "$app/Contents/Info.plist"
xcrun clang -fobjc-arc -Wall -O2 src/bridge.m \
  -framework Cocoa -framework IOKit -framework ApplicationServices \
  -o "$app/Contents/MacOS/NexDockBridge"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built: $app"
