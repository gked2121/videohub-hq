#!/bin/bash
set -e

# Check for Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo "Error: swiftc not found. Install Xcode or Xcode Command Line Tools."
    echo "  xcode-select --install"
    exit 1
fi

echo "[1/4] Compiling VideoHub HQ..."
swiftc -o VideoHubHQ VideoHubHQ.swift -framework SwiftUI -framework AppKit -parse-as-library

echo "[2/4] Packaging app bundle..."
APP="VideoHub HQ.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mv VideoHubHQ "$APP/Contents/MacOS/VideoHubHQ"
cp Info.plist "$APP/Contents/Info.plist"

echo "[3/4] Copying to Desktop..."
rm -rf ~/Desktop/"$APP"
cp -R "$APP" ~/Desktop/

echo "[4/4] Build complete."
echo "  -> ~/Desktop/VideoHub HQ.app"
echo "  Double-click to launch."
