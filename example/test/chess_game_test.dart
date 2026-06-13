import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/chess_game.dart';

void main() {
  group('ChessGame legal move caching', () {
    test('getLegalMoves returns consistent results without moves', () {
      final game = ChessGame();
      final moves1 = game.getLegalMoves();
      final moves2 = game.getLegalMoves();

      // Should return the same list instance (cached)
      expect(identical(moves1, moves2), isTrue);
      // Should have the standard 20 opening moves
      expect(moves1.length, 20);
    });

    test('getLegalMoves cache invalidated after makeMove', () {
      final game = ChessGame();
      final movesBefore = game.getLegalMoves();
      expect(movesBefore.length, 20);

      // Make a move
      final success = game.makeMove('e2e4');
      expect(success, isTrue);

      // After move, cache should be invalidated and new moves computed
      final movesAfter = game.getLegalMoves();
      expect(identical(movesBefore, movesAfter), isFalse);
      // Black should also have 20 opening moves
      expect(movesAfter.length, 20);
    });

    test('getLegalMoves cache invalidated after undoMove', () {
      final game = ChessGame();
      game.makeMove('e2e4');
      final movesAfterE4 = game.getLegalMoves();

      game.undoMove();
      final movesAfterUndo = game.getLegalMoves();

      expect(identical(movesAfterE4, movesAfterUndo), isFalse);
      // Should be back to initial 20 moves
      expect(movesAfterUndo.length, 20);
    });

    test('getLegalMoves cache invalidated after reset', () {
      final game = ChessGame();
      game.makeMove('e2e4');
      game.makeMove('e7e5');
      final movesBeforeReset = game.getLegalMoves();

      game.reset();
      final movesAfterReset = game.getLegalMoves();

      expect(identical(movesBeforeReset, movesAfterReset), isFalse);
      expect(movesAfterReset.length, 20);
    });
  });
}
