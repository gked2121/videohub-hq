#!/bin/bash
set -e

echo "Building VideoHub HQ..."

# Compile
swiftc -o VideoHubHQ VideoHubHQ.swift -framework SwiftUI -framework AppKit -parse-as-library

# Package as .app bundle
APP="VideoHub HQ.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

mv VideoHubHQ "$APP/Contents/MacOS/VideoHubHQ"
cp Info.plist "$APP/Contents/Info.plist"

# Copy to Desktop
cp -R "$APP" ~/Desktop/
echo "Done -- VideoHub HQ.app is on your Desktop."
