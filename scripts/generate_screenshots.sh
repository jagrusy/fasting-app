#!/usr/bin/env bash
set -e

# Solstice App Store Screenshot Generator
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/AppStoreScreenshots"
FASTLANE_SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots/en-US"
TMP_DIR="/tmp/SolsticeScreenshots"

# App Store Connect files screenshots into slots by pixel size, and refuses to accept a
# submission until the required iPhone slots are filled. One device is not enough:
#
#   iPhone 17 Pro Max -> 1320x2868 -> 6.9" slot
#   iPhone 13 Pro Max -> 1284x2778 -> 6.5" slot ("You must upload a screenshot for
#                                                 6.5-inch iPhone displays.")
#
# Pass device names as arguments to override. deliver sorts the combined output into the
# right slots automatically, so both sets live together in the same en-US folder.
DEFAULT_DEVICES=("iPhone 17 Pro Max" "SS-iPhone-13-Pro-Max")
if [ "$#" -gt 0 ]; then
    DEVICES=("$@")
else
    DEVICES=("${DEFAULT_DEVICES[@]}")
fi

echo "📸 Starting Solstice App Store Screenshot Generation..."

rm -rf "$OUTPUT_DIR"; mkdir -p "$OUTPUT_DIR"
rm -rf "$FASTLANE_SCREENSHOTS_DIR"; mkdir -p "$FASTLANE_SCREENSHOTS_DIR"

for SIMULATOR_NAME in "${DEVICES[@]}"; do
    echo "📱 Running UI Screenshot Suite on '$SIMULATOR_NAME'..."

    rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"

    # Runs through the FastedUITests scheme, which is where AppStoreScreenshotTests lives.
    # (The FastedTests scheme is unit-tests-only and cannot run this.)
    xcodebuild test \
        -project "$PROJECT_DIR/Fasted.xcodeproj" \
        -scheme FastedUITests \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
        -only-testing:FastedUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots \
        -quiet

    if [ -z "$(ls -A "$TMP_DIR" 2>/dev/null)" ]; then
        echo "❌ No screenshots produced for '$SIMULATOR_NAME'."
        exit 1
    fi

    # Tag each file with its pixel size so the two device runs cannot overwrite each other
    # and so it is obvious at a glance which App Store slot a given file targets.
    for FILE in "$TMP_DIR"/*.png; do
        BASENAME="$(basename "$FILE" .png)"
        WIDTH="$(sips -g pixelWidth "$FILE" | awk '/pixelWidth/{print $2}')"
        HEIGHT="$(sips -g pixelHeight "$FILE" | awk '/pixelHeight/{print $2}')"
        cp "$FILE" "$OUTPUT_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
        cp "$FILE" "$FASTLANE_SCREENSHOTS_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
    done
done

rm -rf "$TMP_DIR"

echo "🎉 Successfully exported $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots to:"
echo "   $OUTPUT_DIR"
echo "   $FASTLANE_SCREENSHOTS_DIR"
echo
echo "Sizes captured:"
for FILE in "$FASTLANE_SCREENSHOTS_DIR"/*.png; do
    sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixelWidth/{w=$2} /pixelHeight/{print w"x"$2}'
done | sort | uniq -c
