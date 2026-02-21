#!/bin/bash
# Build Automata and package as a DMG for distribution.
# Usage: ./scripts/build-dmg.sh
#
# Prerequisites:
#   - Xcode command line tools installed
#   - Developer ID certificate for signing (optional, for distribution)

set -euo pipefail

APP_NAME="Automata"
BUNDLE_ID="com.macautomata.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="Automata.dmg"

echo "==> Building release..."
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/MacAutomata" "$APP_DIR/Contents/MacOS/MacAutomata"

# Copy Info.plist
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Copy app icon
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

# Copy entitlements
cp Entitlements.entitlements "$APP_DIR/Contents/Resources/"

echo "==> App bundle created at $APP_DIR"

# Sign if DEVELOPER_ID is set
if [ -n "${DEVELOPER_ID:-}" ]; then
    echo "==> Signing with: $DEVELOPER_ID"
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --entitlements Entitlements.entitlements \
        --options runtime \
        "$APP_DIR"
    echo "==> Signed."
else
    echo "==> Skipping code signing (set DEVELOPER_ID to sign)"
fi

# Create DMG
echo "==> Creating DMG..."
rm -f "$DMG_NAME"

# Create a temporary directory for DMG contents
DMG_STAGING="/tmp/mac-automata-dmg"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
cp README.md "$DMG_STAGING/" 2>/dev/null || true
cp LICENSE "$DMG_STAGING/" 2>/dev/null || true
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_NAME"

rm -rf "$DMG_STAGING"

echo "==> Done! DMG created: $DMG_NAME"
echo ""
echo "To notarize (requires DEVELOPER_ID):"
echo "  xcrun notarytool submit $DMG_NAME --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --wait"
echo "  xcrun stapler staple $DMG_NAME"
