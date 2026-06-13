import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/chess_game.dart';

void main() {
  group('ChessGame board state', () {
    test('board getter returns correct initial position', () {
      final game = ChessGame();
      final board = game.board;
      // White rook at a1 = board[7][0]
      expect(board[7][0]?.type, PieceType.rook);
      expect(board[7][0]?.color, PieceColor.white);
      // Black king at e8 = board[0][4]
      expect(board[0][4]?.type, PieceType.king);
      expect(board[0][4]?.color, PieceColor.black);
      // Empty center
      expect(board[4][4], isNull);
    });

    test('board updates after makeMove', () {
      final game = ChessGame();
      game.makeMove('e2e4');
      // e2 (row 6, col 4) should be empty
      expect(game.board[6][4], isNull);
      // e4 (row 4, col 4) should have white pawn
      expect(game.board[4][4]?.type, PieceType.pawn);
      expect(game.board[4][4]?.color, PieceColor.white);
    });

    test('whiteToMove toggles after each move', () {
      final game = ChessGame();
      expect(game.whiteToMove, isTrue);
      game.makeMove('e2e4');
      expect(game.whiteToMove, isFalse);
      game.makeMove('e7e5');
      expect(game.whiteToMove, isTrue);
    });

    test('squareToAlgebraic converts correctly', () {
      final game = ChessGame();
      expect(game.squareToAlgebraic(0, 0), 'a8');
      expect(game.squareToAlgebraic(7, 0), 'a1');
      expect(game.squareToAlgebraic(7, 4), 'e1');
      expect(game.squareToAlgebraic(0, 7), 'h8');
    });

    test('undoMove restores previous board state', () {
      final game = ChessGame();
      final boardBefore = game.board.map((r) => r.map((p) => p?.symbol).toList()).toList();
      game.makeMove('e2e4');
      game.undoMove();
      final boardAfter = game.board.map((r) => r.map((p) => p?.symbol).toList()).toList();
      expect(boardAfter, equals(boardBefore));
    });

    test('reset restores initial position', () {
      final game = ChessGame();
      game.makeMove('e2e4');
      game.makeMove('e7e5');
      game.reset();
      expect(game.whiteToMove, isTrue);
      expect(game.board[6][4]?.type, PieceType.pawn); // e2 pawn back
    });
  });
}
