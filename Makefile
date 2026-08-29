PROJECT_NAME = Fasted
SCHEME_IOS = Fasted
SCHEME_WATCH = FastedWatch
SCHEME_TESTS = FastedTests
SCHEME_UI_TESTS = FastedUITests

# Dynamically discover first available iPhone simulator on the machine
SIM_NAME := $(shell xcrun simctl list devices available -j 2>/dev/null | jq -r '.devices[] | select(. != []) | .[] | select(.isAvailable == true and (.name | contains("iPhone"))) | .name' | head -n 1)
ifeq ($(SIM_NAME),)
SIM_NAME := iPhone 16
endif

DESTINATION_IOS = 'platform=iOS Simulator,name=$(SIM_NAME)'
DESTINATION_WATCH = 'generic/platform=watchOS Simulator'

.PHONY: all build build-ios build-watch test uitest lint hooks clean beta-local

all: lint build test

hooks:
	chmod +x scripts/pre-commit scripts/pre-push scripts/pre-commit.sh scripts/pre-push.sh
	git config core.hooksPath scripts
	@echo "✅ Git hooks configured to run locally (.git/hooks -> scripts/)"

build: build-ios

build-ios:
	@echo "🔨 Building with simulator target: $(SIM_NAME)"
	xcodebuild build \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_IOS) \
		-destination $(DESTINATION_IOS) \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
		-quiet

build-watch:
	xcodebuild build \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_WATCH) \
		-destination $(DESTINATION_WATCH) \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES


test:
	@echo "🧪 Running Unit Tests with simulator target: $(SIM_NAME)"
	xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_TESTS) \
		-destination $(DESTINATION_IOS) \
		-resultBundlePath TestResults-Unit.xcresult

uitest:
	@echo "📱 Running UI Tests with simulator target: $(SIM_NAME)"
	xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_UI_TESTS) \
		-destination $(DESTINATION_IOS) \
		-resultBundlePath TestResults-UI.xcresult

lint:
	@if which swiftlint >/dev/null; then \
		swiftlint lint --strict; \
	else \
		echo "SwiftLint not installed locally. Skipping local lint check (will run in CI)."; \
	fi

clean:
	rm -rf build DerivedData *.xcresult

# Builds and uploads to TestFlight using YOUR local Xcode signing (Xcode > Settings > Accounts),
# instead of the GitHub Actions deploy workflow, which currently has no distribution certificate
# configured. Requires APPLE_TEAM_ID, e.g.: APPLE_TEAM_ID=ABCDE12345 make beta-local
beta-local:
	bundle exec fastlane beta_local
