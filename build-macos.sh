#!/bin/bash
set -e

echo "🏗️  Building Stockfish for macOS..."
cd "$(dirname "$0")/example"

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

BUILD_MODE="${1:-debug}"
BUILD_MODE_CAP="$(tr '[:lower:]' '[:upper:]' <<< ${BUILD_MODE:0:1})${BUILD_MODE:1}"

echo "🔨 Building in $BUILD_MODE mode..."

flutter build macos --$BUILD_MODE 2>/dev/null || true

FLUTTER_BUILD_HASH=$(ls -t .dart_tool/flutter_build/ 2>/dev/null | head -n1)

if [ -z "$FLUTTER_BUILD_HASH" ]; then
    flutter build macos --$BUILD_MODE
else
    export FLUTTER_BUILD_DIR=".dart_tool/flutter_build/$FLUTTER_BUILD_HASH"
    echo "📍 Using FLUTTER_BUILD_DIR: $FLUTTER_BUILD_DIR"
    flutter build macos --$BUILD_MODE
fi

DYLIB_SOURCE=$(find .dart_tool/hooks_runner/shared/stockfish/build -name "libstockfish.dylib" 2>/dev/null | head -n1)

if [ -z "$DYLIB_SOURCE" ]; then
    echo "❌ Could not find libstockfish.dylib"
    exit 1
fi

echo "📚 Found dylib: $DYLIB_SOURCE"

# Copy dylib
FRAMEWORK_DIR="build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app/Contents/Frameworks/stockfish.framework"
mkdir -p "$FRAMEWORK_DIR"
cp "$DYLIB_SOURCE" "$FRAMEWORK_DIR/stockfish"
chmod +x "$FRAMEWORK_DIR/stockfish"

# Copy NNUE files to Resources
RESOURCES_DIR="build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app/Contents/Resources"
echo "📦 Copying NNUE network files..."
cp ../macos/src/stockfish/nnue/nn-1111cefa1111.nnue "$RESOURCES_DIR/"
cp ../macos/src/stockfish/nn-37f18f62d772.nnue "$RESOURCES_DIR/"

echo "✅ Build complete!"
echo "📱 App location: build/macos/Build/Products/${BUILD_MODE_CAP}/Runner.app"