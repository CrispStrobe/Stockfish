#!/bin/bash

# build-macos.sh - Build script for Stockfish Flutter plugin on macOS
set -e

echo "🏗️  Building Stockfish for macOS..."

cd "$(dirname "$0")/example"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Determine the build mode (default: debug)
BUILD_MODE="${1:-debug}"

if [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "profile" ]; then
    echo "❌ Invalid build mode: $BUILD_MODE"
    echo "Usage: ./build-macos.sh [debug|release|profile]"
    exit 1
fi

echo "🔨 Building in $BUILD_MODE mode..."

# Create a temporary build to get the build directory
flutter build macos --$BUILD_MODE 2>/dev/null || true

# Find the most recent flutter_build directory
FLUTTER_BUILD_HASH=$(ls -t .dart_tool/flutter_build/ 2>/dev/null | head -n1)

if [ -z "$FLUTTER_BUILD_HASH" ]; then
    echo "⚠️  Could not find flutter_build directory, trying without FLUTTER_BUILD_DIR..."
    flutter build macos --$BUILD_MODE
else
    export FLUTTER_BUILD_DIR=".dart_tool/flutter_build/$FLUTTER_BUILD_HASH"
    echo "📍 Using FLUTTER_BUILD_DIR: $FLUTTER_BUILD_DIR"
    flutter build macos --$BUILD_MODE
fi

# Find the built dylib
BUILD_MODE_CAP="$(tr '[:lower:]' '[:upper:]' <<< ${BUILD_MODE:0:1})${BUILD_MODE:1}"
DYLIB_SOURCE=$(find .dart_tool/hooks_runner/shared/stockfish/build -name "libstockfish.dylib" 2>/dev/null | head -n1)

if [ -z "$DYLIB_SOURCE" ]; then
    echo "❌ Could not find libstockfish.dylib"
    exit 1
fi

echo "📚 Found dylib: $DYLIB_SOURCE"

# Copy dylib to app bundle
FRAMEWORK_DIR="build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app/Contents/Frameworks/stockfish.framework"
echo "📦 Creating framework directory: $FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR"

echo "📋 Copying dylib to framework..."
cp "$DYLIB_SOURCE" "$FRAMEWORK_DIR/stockfish"
chmod +x "$FRAMEWORK_DIR/stockfish"

# Verify the copy
if [ -f "$FRAMEWORK_DIR/stockfish" ]; then
    echo "✅ Dylib successfully embedded"
    ls -lh "$FRAMEWORK_DIR/stockfish"
else
    echo "❌ Failed to embed dylib"
    exit 1
fi

echo "✅ Build complete!"
echo "📱 App location: build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app"
echo ""
echo "To run the app:"
echo "  flutter run -d macos --$BUILD_MODE"
echo "Or open directly:"
echo "  open build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app"