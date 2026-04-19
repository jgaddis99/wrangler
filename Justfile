# Wrangler build tasks

# Generate Xcode project
generate:
    xcodegen generate

# Build debug
build:
    xcodegen generate && xcodebuild build -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug

# Run tests
test:
    xcodegen generate && xcodebuild test -project Wrangler.xcodeproj -scheme Wrangler -configuration Debug -destination 'platform=macOS'

# Build DMG for distribution
dmg:
    ./scripts/build-dmg.sh

# Clean build artifacts
clean:
    rm -rf build/ DerivedData/ Wrangler.xcodeproj/
