#!/bin/bash
set -euo pipefail

echo "🚀 [pre-push] Running local validation before pushing to remote..."

# 1. Discover active simulator dynamically
SIM_NAME=$(xcrun simctl list devices available -j | jq -r '.devices[] | select(. != []) | .[] | select(.isAvailable == true and (.name | contains("iPhone"))) | .name' 2>/dev/null | head -n 1)

if [ -z "$SIM_NAME" ]; then
    echo "⚠️  [pre-push] No active iPhone simulator found. Skipping local unit tests."
    exit 0
fi

echo "📱 [pre-push] Testing against available simulator: $SIM_NAME"

# 2. Compile application with warnings as errors
echo "🔨 [pre-push] Building iOS Application..."
xcodebuild build \
    -project Fasted.xcodeproj \
    -scheme Fasted \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -quiet

# 3. Run Unit Test suite (Fast feedback)
echo "🧪 [pre-push] Running FastedTests Unit Test Suite..."
xcodebuild test \
    -project Fasted.xcodeproj \
    -scheme FastedTests \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -quiet

echo "🎉 [pre-push] All local checks and unit tests PASSED! Safe to push to remote."
