#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Villblomst.app"
BUILD="$ROOT/.build"

rm -rf "$APP" "$BUILD"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "1/4  Tegner app-ikon …"
if swift "$ROOT/Tools/makeicon.swift" "$BUILD/AppIcon.iconset" >/dev/null 2>&1; then
    iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
else
    echo "     (hopper over ikon)"
fi

echo "2/4  Kompilerer Swift …"
SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
swiftc -O -parse-as-library -swift-version 5 \
    -sdk "$SDK" \
    -framework SwiftUI -framework AppKit \
    "$ROOT"/Sources/*.swift \
    -o "$APP/Contents/MacOS/Villblomst"

echo "3/4  Skriver Info.plist …"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "4/4  Signerer (ad-hoc) …"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Ferdig: $APP"
