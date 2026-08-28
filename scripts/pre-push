#!/bin/bash
set -euo pipefail

echo "🚀 [pre-push] Running local validation before pushing to remote..."

# 1. SwiftLint — mirrors the CI "SwiftLint" job (swiftlint lint --strict). Hard fail, since a
#    lint violation here is a lint violation in CI; unlike pre-commit's soft warning, pre-push is
#    the last local gate before code reaches GitHub, so this must not be skippable.
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "⚙️  [pre-push] SwiftLint not found locally, installing via Homebrew..."
    brew install swiftlint
fi

echo "🔍 [pre-push] Running SwiftLint (--strict)..."
swiftlint lint --strict
echo "✅ [pre-push] SwiftLint passed (0 violations)"

# 2. Discover active simulator dynamically, falling back to a known device name instead of
#    silently skipping all checks if `jq` is missing or its output is empty for any reason
#    (matches the fallback already used in the Makefile).
SIM_NAME=$(xcrun simctl list devices available -j 2>/dev/null | jq -r '.devices[] | select(. != []) | .[] | select(.isAvailable == true and (.name | contains("iPhone"))) | .name' 2>/dev/null | head -n 1)
if [ -z "$SIM_NAME" ]; then
    SIM_NAME="iPhone 16"
fi
echo "📱 [pre-push] Testing against simulator: $SIM_NAME"

# 3. Build with warnings-as-errors — mirrors CI's dedicated "Build iOS Application" step.
#    `xcodebuild test` alone builds first but does NOT apply this flag, so a new warning that
#    would fail CI's build step could otherwise pass straight through pre-push.
echo "🔨 [pre-push] Building (warnings-as-errors)..."
xcodebuild build \
    -project Fasted.xcodeproj \
    -scheme Fasted \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    -quiet

# 4. Run Test Suite (incremental build & test)
echo "🧪 [pre-push] Running FastedTests Suite..."
xcodebuild test \
    -project Fasted.xcodeproj \
    -scheme FastedTests \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -quiet

echo "🎉 [pre-push] All local checks and tests PASSED! Safe to push to remote."
