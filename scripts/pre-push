#!/bin/bash
set -euo pipefail

echo "🚀 [pre-push] Running local validation before pushing to remote..."

# 1. Discover active simulator dynamically
SIM_NAME=$(xcrun simctl list devices available -j | jq -r '.devices[] | select(. != []) | .[] | select(.isAvailable == true and (.name | contains("iPhone"))) | .name' 2>/dev/null | head -n 1)

if [ -z "$SIM_NAME" ]; then
    echo "⚠️  [pre-push] No active iPhone simulator found. Skipping local tests."
    exit 0
fi

echo "📱 [pre-push] Testing against available simulator: $SIM_NAME"

# 2. Run Test Suite (incremental build & test)
echo "🧪 [pre-push] Running FastedTests Suite..."
xcodebuild test \
    -project Fasted.xcodeproj \
    -scheme FastedTests \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -quiet

echo "🎉 [pre-push] All local checks and tests PASSED! Safe to push to remote."
