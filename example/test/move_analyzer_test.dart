import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/move_analyzer.dart';

void main() {
  group('MoveAnalyzer', () {
    test('analyzeInIsolate returns annotation for opening move', () {
      final request = AnalysisRequest(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMove: 'e2e4',
        evaluation: MoveEvaluation(
          scoreBefore: 0.0,
          scoreAfter: 0.3,
          bestMove: 'e2e4',
          bestMoveScore: 0.3,
          depth: 10,
          whiteToMove: true,
        ),
      );
      final annotation = analyzeInIsolate(request);
      expect(annotation.move, 'e2e4');
      expect(annotation.gamePhase, GamePhase.opening);
    });

    test('MoveEvaluation quality thresholds', () {
      // Good move (slight improvement)
      final good = MoveEvaluation(
        scoreBefore: 0.0,
        scoreAfter: 0.2,
        bestMove: 'e2e4',
        bestMoveScore: 0.3,
        depth: 10,
        whiteToMove: true,
      );
      expect(good.quality, MoveQuality.good);

      // Blunder (big loss)
      final blunder = MoveEvaluation(
        scoreBefore: 0.0,
        scoreAfter: -4.0,
        bestMove: 'e2e4',
        bestMoveScore: 0.3,
        depth: 10,
        whiteToMove: true,
      );
      expect(blunder.quality, MoveQuality.blunder);
    });
  });
}
