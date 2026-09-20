#!/usr/bin/env bash
set -e

# Solstice App Store Screenshot Generator
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/AppStoreScreenshots"
FASTLANE_SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots/en-US"
TMP_DIR="/tmp/SolsticeScreenshots"

# App Store Connect files screenshots into slots by pixel size, and refuses to accept a
# submission until the required iPhone and Watch slots are filled:
#
#   iPhone 17 Pro Max      -> 1320x2868 -> 6.9" iPhone slot
#   SS-iPhone-13-Pro-Max   -> 1284x2778 -> 6.5" iPhone slot
#   Apple Watch SE (44mm)  -> 368x448   -> Apple Watch Series 4+ slot
#   Apple Watch Ultra      -> 422x514   -> Apple Watch Ultra slot
#
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

    for FILE in "$TMP_DIR"/*.png; do
        [ -f "$FILE" ] || continue
        BASENAME="$(basename "$FILE" .png)"
        WIDTH="$(sips -g pixelWidth "$FILE" | awk '/pixelWidth/{print $2}')"
        HEIGHT="$(sips -g pixelHeight "$FILE" | awk '/pixelHeight/{print $2}')"
        cp "$FILE" "$OUTPUT_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
        cp "$FILE" "$FASTLANE_SCREENSHOTS_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
    done
done

# Apple Watch Screenshots
echo "⌚ Discovering available Apple Watch simulators..."
WATCH_DEVICES=()

WATCH_44MM=$(xcrun simctl list devices available -j 2>/dev/null | jq -r '.devices | to_entries[] | .value[] | select(.isAvailable == true and (.name | contains("44mm"))) | .name' | head -n 1)
if [ -n "$WATCH_44MM" ]; then
    WATCH_DEVICES+=("$WATCH_44MM")
fi

WATCH_ULTRA=$(xcrun simctl list devices available -j 2>/dev/null | jq -r '.devices | to_entries[] | .value[] | select(.isAvailable == true and (.name | contains("Ultra"))) | .name' | head -n 1)
if [ -n "$WATCH_ULTRA" ]; then
    WATCH_DEVICES+=("$WATCH_ULTRA")
fi

if [ "${#WATCH_DEVICES[@]}" -gt 0 ]; then
    echo "⌚ Building FastedWatch application..."
    WATCH_BUILD_DIR="$PROJECT_DIR/build/DerivedDataWatch"
    rm -rf "$WATCH_BUILD_DIR"
    xcodebuild build \
        -project "$PROJECT_DIR/Fasted.xcodeproj" \
        -scheme FastedWatch \
        -destination "generic/platform=watchOS Simulator" \
        -derivedDataPath "$WATCH_BUILD_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        -quiet

    WATCH_APP="$WATCH_BUILD_DIR/Build/Products/Debug-watchsimulator/FastedWatch.app"
    if [ ! -d "$WATCH_APP" ]; then
        echo "❌ Watch app not found at $WATCH_APP"
        exit 1
    fi

    for WATCH_SIM in "${WATCH_DEVICES[@]}"; do
        echo "⌚ Capturing Watch screenshots on '$WATCH_SIM'..."
        rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"

        xcrun simctl boot "$WATCH_SIM" 2>/dev/null || true
        xcrun simctl bootstatus "$WATCH_SIM" -b
        xcrun simctl install "$WATCH_SIM" "$WATCH_APP"

        # 1. Active Fast (80% Progress)
        xcrun simctl terminate "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" 2>/dev/null || true
        xcrun simctl launch "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" -seedScreenshots80
        sleep 3
        xcrun simctl io "$WATCH_SIM" screenshot "$TMP_DIR/01_Watch_ActiveFast.png"

        # 2. Goal Reached (105% Progress)
        xcrun simctl terminate "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" 2>/dev/null || true
        xcrun simctl launch "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" -seedScreenshots100
        sleep 3
        xcrun simctl io "$WATCH_SIM" screenshot "$TMP_DIR/02_Watch_GoalReached.png"

        # 3. Ready to Fast (Idle)
        xcrun simctl terminate "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" 2>/dev/null || true
        xcrun simctl launch "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp"
        sleep 3
        xcrun simctl io "$WATCH_SIM" screenshot "$TMP_DIR/03_Watch_ReadyToFast.png"

        xcrun simctl terminate "$WATCH_SIM" "com.grusy.SolsticeFast.watchkitapp" 2>/dev/null || true
        xcrun simctl shutdown "$WATCH_SIM" 2>/dev/null || true

        for FILE in "$TMP_DIR"/*.png; do
            [ -f "$FILE" ] || continue
            BASENAME="$(basename "$FILE" .png)"
            WIDTH="$(sips -g pixelWidth "$FILE" | awk '/pixelWidth/{print $2}')"
            HEIGHT="$(sips -g pixelHeight "$FILE" | awk '/pixelHeight/{print $2}')"
            cp "$FILE" "$OUTPUT_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
            cp "$FILE" "$FASTLANE_SCREENSHOTS_DIR/${BASENAME}_${WIDTH}x${HEIGHT}.png"
        done
    done
fi

rm -rf "$TMP_DIR"

echo "🎉 Successfully exported $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ') screenshots to:"
echo "   $OUTPUT_DIR"
echo "   $FASTLANE_SCREENSHOTS_DIR"
echo
echo "Sizes captured:"
for FILE in "$FASTLANE_SCREENSHOTS_DIR"/*.png; do
    sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixelWidth/{w=$2} /pixelHeight/{print w"x"$2}'
done | sort | uniq -c
