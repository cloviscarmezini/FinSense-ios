#!/bin/bash
set -e

# Log for verification & debugging
LOG_FILE="/tmp/finsense_install.log"
echo "=== $(date): FinSense Build & Install Triggered ===" >> "$LOG_FILE"
echo "TARGET_DEVICE_IDENTIFIER: ${TARGET_DEVICE_IDENTIFIER}" >> "$LOG_FILE"
echo "BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}" >> "$LOG_FILE"
echo "SRCROOT: ${SRCROOT}" >> "$LOG_FILE"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "$SRCROOT" ]; then
    PROJECT_ROOT="$SRCROOT"
fi

# Locate the compiled FinSense executable
EXECUTABLE_PATH=""
if [ -n "$BUILT_PRODUCTS_DIR" ] && [ -f "$BUILT_PRODUCTS_DIR/FinSense" ]; then
    EXECUTABLE_PATH="$BUILT_PRODUCTS_DIR/FinSense"
elif [ -f "$PROJECT_ROOT/build/FinSense.app/FinSense" ]; then
    EXECUTABLE_PATH="$PROJECT_ROOT/build/FinSense.app/FinSense"
fi

APP_BUNDLE_DIR="$PROJECT_ROOT/build/FinSense.app"
if [ -n "$BUILT_PRODUCTS_DIR" ]; then
    APP_BUNDLE_DIR="$BUILT_PRODUCTS_DIR/FinSense.app"
fi

# Assemble / update the .app bundle
mkdir -p "$APP_BUNDLE_DIR"
if [ -n "$EXECUTABLE_PATH" ] && [ "$EXECUTABLE_PATH" != "$APP_BUNDLE_DIR/FinSense" ]; then
    cp "$EXECUTABLE_PATH" "$APP_BUNDLE_DIR/FinSense"
fi
cp "$PROJECT_ROOT/Info.plist" "$APP_BUNDLE_DIR/Info.plist"
codesign --force --sign - --timestamp=none "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1

# Keep project root build/ directory synchronized
if [ "$APP_BUNDLE_DIR" != "$PROJECT_ROOT/build/FinSense.app" ]; then
    mkdir -p "$PROJECT_ROOT/build"
    rm -rf "$PROJECT_ROOT/build/FinSense.app"
    cp -R "$APP_BUNDLE_DIR" "$PROJECT_ROOT/build/FinSense.app"
fi

# Determine target simulator UDID
DEVICE_ID="${TARGET_DEVICE_IDENTIFIER}"

# If not provided by Xcode env or placeholder, look for booted iPhone 18 Pro
if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "placeholder" ] || [[ "$DEVICE_ID" == dvtdevice* ]]; then
    DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 18 Pro" | grep "Booted" | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
fi

# If still empty, look for any booted iPhone
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun simctl list devices | grep -i "iphone" | grep "Booted" | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
fi

# If still empty, find any iPhone 18 Pro device (even if shutdown)
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 18 Pro" | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
fi

# Fallback to default iPhone 18 Pro
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="E70E682A-0D28-4887-A345-380BDC015123"
fi

echo "Selected Device: $DEVICE_ID" >> "$LOG_FILE"

# Boot device if not already booted
DEVICE_STATUS=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "Booted" || true)
if [ "$DEVICE_STATUS" != "Booted" ]; then
    echo "Booting $DEVICE_ID..." >> "$LOG_FILE"
    xcrun simctl boot "$DEVICE_ID" 2>> "$LOG_FILE" || true
fi

# Install the app
echo "Installing to $DEVICE_ID..." >> "$LOG_FILE"
xcrun simctl install "$DEVICE_ID" "$APP_BUNDLE_DIR" >> "$LOG_FILE" 2>&1

# Launch or focus DeviceHub (replaces old Simulator.app)
echo "Launching DeviceHub..." >> "$LOG_FILE"
open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" 2>> "$LOG_FILE" || true

# Launch the app bundle
echo "Launching br.com.finsense.ios..." >> "$LOG_FILE"
xcrun simctl launch "$DEVICE_ID" br.com.finsense.ios >> "$LOG_FILE" 2>&1

echo "=== FinSense successfully deployed and launched ===" >> "$LOG_FILE"
