export 'src/stockfish_state.dart';

// Platform-specific exports
export 'src/stockfish_web.dart' if (dart.library.io) 'src/stockfish.dart';