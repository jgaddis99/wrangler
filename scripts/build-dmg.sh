#!/bin/bash
# Build Wrangler.app and package into a DMG for distribution.
# Usage: ./scripts/build-dmg.sh
#
# Prerequisites:
# - xcodegen installed (brew install xcodegen)
# - Xcode command line tools
# - Local.xcconfig with DEVELOPMENT_TEAM set

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

APP_NAME="Wrangler"
VERSION=$(grep MARKETING_VERSION project.yml | head -1 | awk '{print $2}' | tr -d '"')
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"

echo "=== Building $APP_NAME v$VERSION ==="

# Generate Xcode project
echo "→ Generating Xcode project..."
xcodegen generate

# Build Release
echo "→ Building Release..."
xcodebuild build \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="Apple Development" \
    2>&1 | tail -5

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_PATH not found"
    exit 1
fi

echo "→ App built at: $APP_PATH"

# Create DMG
echo "→ Creating DMG..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
