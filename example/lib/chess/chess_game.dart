import 'package:chess/chess.dart' as chess;
import 'dart:developer' as dev;

class ChessGame {
  final chess.Chess _game = chess.Chess();

  // The visual board needs this to sync
  String get currentFEN => _game.fen;

  // The Stockfish logic needs this
  List<String> get moveHistory => _game.history
      .map((m) => '${m.move.fromAlgebraic}${m.move.toAlgebraic}${m.move.promotion?.name ?? ""}')
      .toList();

  String get positionCommand {
    final cmd = moveHistory.isEmpty 
        ? 'position startpos' 
        : 'position startpos moves ${moveHistory.join(' ')}';
    return cmd;
  }

  /// VALIDATION LOGIC WITH VERBOSE LOGGING
  bool makeMove(String uciMove) {
    print('--- CHESS LOGIC DEBUG ---');
    print('Checking move: $uciMove');
    print('Current Turn: ${_game.turn == chess.Color.WHITE ? "White" : "Black"}');
    
    // FIX: Parse the UCI string (e.g., "e2e4" or "a7a8q")
    if (uciMove.length < 4) return false;
    
    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;

    // FIX: Pass a Map to the .move() method instead of the raw string
    bool success = _game.move({
      'from': from, 
      'to': to, 
      'promotion': promotion
    });

    if (success) {
      print('✅ MOVE LEGAL');
    } else {
      print('❌ MOVE ILLEGAL!');
      // print('List of legal moves currently available: ${_game.moves()}');
      print('-------------------------');
    }
    return success;
  }

  // GAME OVER HELPERS
  bool get isGameOver => _game.game_over;

  String get gameOverReason {
    if (_game.in_checkmate) return 'Checkmate!';
    if (_game.in_draw) return 'Draw';
    if (_game.in_stalemate) return 'Stalemate!';
    if (_game.in_threefold_repetition) return 'Threefold Repetition!';
    return 'Game Over';
  }

  String? get winner {
    if (!_game.in_checkmate) return null;
    return _game.turn == chess.Color.WHITE ? 'Black' : 'White';
  }

  void undoMove() => _game.undo();
  void reset() => _game.reset();
}