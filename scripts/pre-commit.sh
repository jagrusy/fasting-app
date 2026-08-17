#!/bin/bash
set -euo pipefail

# Fast, lightweight checks before committing changes

echo "🔍 [pre-commit] Checking code formatting and linting..."

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict --quiet
    echo "✅ [pre-commit] SwiftLint passed (0 violations)"
else
    echo "⚠️  [pre-commit] SwiftLint not found locally (will run in CI)"
fi

# Ensure project generation is up to date if project.yml changed
if git diff --cached --name-only | grep -q "project.yml"; then
    if command -v xcodegen >/dev/null 2>&1; then
        echo "⚙️  [pre-commit] Regenerating Fasted.xcodeproj from project.yml..."
        xcodegen generate --quiet
        git add Fasted.xcodeproj
    fi
fi

echo "✅ [pre-commit] Clean commit ready"
