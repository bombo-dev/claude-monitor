#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeMonitor"
BUILD_DIR="$PROJECT_DIR/.build/debug"
BUNDLE_DIR="$PROJECT_DIR/.build/${APP_NAME}.app"

echo "Building..."
cd "$PROJECT_DIR"
swift build

echo "Creating .app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Sources/$APP_NAME/App/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

# Add CFBundleIdentifier and CFBundleExecutable to Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.bombo.ClaudeMonitor" "$BUNDLE_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$BUNDLE_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$BUNDLE_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$BUNDLE_DIR/Contents/Info.plist" 2>/dev/null || true

echo "Bundle created: $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
