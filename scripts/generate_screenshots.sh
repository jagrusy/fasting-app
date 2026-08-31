#!/usr/bin/env bash
set -e

# Solstice App Store Screenshot Generator
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/AppStoreScreenshots"
FASTLANE_SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots/en-US"
TMP_DIR="/tmp/SolsticeScreenshots"

echo "📸 Starting Solstice App Store Screenshot Generation..."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
rm -rf "$FASTLANE_SCREENSHOTS_DIR"
mkdir -p "$FASTLANE_SCREENSHOTS_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

SIMULATOR_NAME="${1:-iPhone 17 Pro}"

echo "📱 Running UI Screenshot Suite on '$SIMULATOR_NAME'..."

xcodebuild test \
    -project "$PROJECT_DIR/Fasted.xcodeproj" \
    -scheme FastedUITests \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -only-testing:FastedUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots \
    -quiet

if [ -d "$TMP_DIR" ]; then
    cp -R "$TMP_DIR/"* "$OUTPUT_DIR/"
    cp -R "$TMP_DIR/"* "$FASTLANE_SCREENSHOTS_DIR/"
    echo "🎉 Successfully exported $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots to:"
    echo "   $OUTPUT_DIR"
    echo "   $FASTLANE_SCREENSHOTS_DIR"
else
    echo "❌ No screenshots found in temporary directory."
    exit 1
fi
