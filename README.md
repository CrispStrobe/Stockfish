# stockfish
![Pipeline](https://github.com/ArjanAswal/Stockfish/actions/workflows/pipeline.yml/badge.svg)

The Stockfish Chess Engine for Flutter.

Also check out [The Leela Chess Zero (lc0)](https://pub.dev/packages/leela_chess_zero) neural network chess engine for flutter.

## Platform Support

- ✅ Android (was working already in original release, yet untested in this fork)
- ✅ iOS (was working already in original release, yet untested in this fork)
- ✅ macOS (via hooks-based native build)
- ✅ Windows (via FFI plugin, WIP)

## Architecture

This package wraps the **Stockfish chess engine** (C++) for use in Flutter applications on Android, iOS, macOS, and Windows. It uses **Dart FFI (Foreign Function Interface)** to communicate between Dart and native C++ code.

For more information go to [architecture.md](architecture.md).

## macOS Build System

The macOS implementation uses Flutter's **hooks** system (the modern replacement for `native_assets_cli`) to compile the Stockfish C++ engine. This approach:

- Uses `native_toolchain_c` ^0.17.0 for C++ compilation
- Disables NNUE embedding (`NNUE_EMBEDDING_OFF`) to avoid inline assembly issues
- Requires manual dylib placement due to (afaik) Flutter quirks with `FLUTTER_BUILD_DIR`

### Building for macOS

Use the provided build script:

```bash
# Debug build (default)
./build-macos.sh

# Release build
./build-macos.sh release

# Profile build
./build-macos.sh profile
```

The script automatically:
1. Cleans previous builds
2. Compiles the Stockfish engine using hooks
3. Sets the required `FLUTTER_BUILD_DIR` environment variable
4. Copies the compiled library to the app bundle
5. Makes the library executable

### Manual Build

If you need to build manually:

```bash
cd example
export FLUTTER_BUILD_DIR=".dart_tool/flutter_build/$(ls -t .dart_tool/flutter_build/ | head -n1)"
flutter build macos --debug

# Copy the dylib to the app bundle
mkdir -p build/macos/Build/Products/Debug/Runner.app/Contents/Frameworks/stockfish.framework
cp .dart_tool/hooks_runner/shared/stockfish/build/*/libstockfish.dylib \
   build/macos/Build/Products/Debug/Runner.app/Contents/Frameworks/stockfish.framework/stockfish
chmod +x build/macos/Build/Products/Debug/Runner.app/Contents/Frameworks/stockfish.framework/stockfish
```

### Technical Details

**Dependencies** (in `pubspec.yaml`):
```yaml
dependencies:
  hooks: ^1.0.0
  code_assets: ^1.0.0
  native_toolchain_c: ^0.17.0
```

**Build Hook** (`hook/build.dart`):
- Compiles all Stockfish C++ sources
- Uses `-std=c++17` flag
- Defines `NNUE_EMBEDDING_OFF` to disable neural network embedding
- Links against C++ standard library via `language: Language.cpp`

**Known Issues**:
- Flutter's `xcode_backend.dart` raises a null check error when `FLUTTER_BUILD_DIR` is not set
- The dylib must for now be manually copied to `stockfish.framework/stockfish` in the app bundle
- NNUE neural networks are not embedded; Stockfish will attempt to load them at runtime (this may cause initialization warnings but should not prevent basic functionality)

## Example

Check out this [working chess game](https://github.com/PScottZero/EnPassant/tree/stockfish) using the original flutter stockfish package by [@PScottZero](https://github.com/PScottZero).

Also see the [example](example) folder for a minimal Flutter app demonstrating usage.

## Usage

**iOS Requirements**: iOS project must have `IPHONEOS_DEPLOYMENT_TARGET` >= 12.0.

**macOS Requirements**: macOS 13.0 or later.

### Add dependency

Update `dependencies` section inside `pubspec.yaml`:

```yaml
dependencies:
  stockfish: ^1.7.0
```

### Init engine

```dart
import 'package:stockfish/stockfish.dart';

// create a new instance
final stockfish = Stockfish();

// state is a ValueListenable<StockfishState>
print(stockfish.state.value); // StockfishState.starting

// the engine takes a few moment to start
await Future.delayed(...)
print(stockfish.state.value); // StockfishState.ready
```

### UCI command

Waits until the state is ready before sending commands.

```dart
stockfish.stdin = 'isready';
stockfish.stdin = 'go movetime 3000';
stockfish.stdin = 'go infinite';
stockfish.stdin = 'stop';
```

Engine output is directed to a `Stream<String>`, add a listener to process results.

```dart
stockfish.stdout.listen((line) {
  // do something useful
  print(line);
});
```

### Dispose / Hot reload

There are two active isolates when Stockfish engine is running. That interferes with Flutter's hot reload feature so you need to dispose it before attempting to reload.

```dart
// sends the UCI quit command
stockfish.stdin = 'quit';
// or even easier...
stockfish.dispose();
```

**Note**: Only one instance can be created at a time. The factory method `Stockfish()` will throw a `StateError` if called when an existing instance is active.

## Development

### Project Structure

```
stockfish/
├── hook/
│   └── build.dart          # macOS native build hook
├── macos/
│   ├── src/
│   │   ├── ffi.cpp         # FFI bridge
│   │   └── stockfish/      # Stockfish engine sources
│   └── Resources/          # macOS resources
├── lib/
│   └── src/
│       ├── ffi.dart        # FFI bindings
│       └── stockfish.dart  # Dart API
├── build-macos.sh          # macOS build automation script
└── pubspec.yaml
```

### Contributing

When submitting PRs that modify the macOS build:
1. Test with `./build-macos.sh debug`
2. Verify the app launches without FFI errors
3. Check that Stockfish responds to UCI commands

## License

See [LICENSE](LICENSE) file.

## Credits

- Original package: [@ArjanAswal](https://github.com/ArjanAswal)
- Stockfish engine: [Stockfish team](https://stockfishchess.org/)
