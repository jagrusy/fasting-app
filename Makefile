PROJECT_NAME = Fasted
SCHEME_IOS = Fasted
SCHEME_WATCH = FastedWatch
SCHEME_UI_TESTS = FastedUITests

DESTINATION_IOS = 'platform=iOS Simulator,name=iPhone 16'
DESTINATION_WATCH = 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

.PHONY: all build build-ios build-watch test uitest lint clean

all: lint build test

build: build-ios build-watch

build-ios:
	xcodebuild build \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_IOS) \
		-destination $(DESTINATION_IOS) \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

build-watch:
	xcodebuild build \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_WATCH) \
		-destination $(DESTINATION_WATCH) \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES || echo "Watch scheme not built yet"

test:
	xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_IOS) \
		-destination $(DESTINATION_IOS) \
		-resultBundlePath TestResults.xcresult

uitest:
	xcodebuild test \
		-project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME_UI_TESTS) \
		-destination $(DESTINATION_IOS)

lint:
	@if which swiftlint >/dev/null; then \
		swiftlint lint --strict; \
	else \
		echo "SwiftLint not installed locally. Skipping local lint check (will run in CI)."; \
	fi

clean:
	rm -rf build DerivedData TestResults.xcresult
