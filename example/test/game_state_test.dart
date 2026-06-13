import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/game_state.dart';

void main() {
  group('GameState', () {
    test('default values are correct', () {
      const state = GameState();
      expect(state.strengthLevel, 10);
      expect(state.hintDepth, 15);
      expect(state.showValidMoves, true);
      expect(state.animateMoves, true);
      expect(state.selectedRow, isNull);
      expect(state.selectedCol, isNull);
      expect(state.validMoves, isEmpty);
      expect(state.statusMessage, 'Your turn (White)');
      expect(state.isThinking, false);
      expect(state.hintMove, isNull);
      expect(state.lastMove, '');
      expect(state.waitingForHint, false);
      expect(state.analysisExpanded, false);
      expect(state.currentBestMove, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final state = const GameState(
        strengthLevel: 5,
        hintDepth: 20,
        showValidMoves: false,
        selectedRow: 3,
        selectedCol: 4,
        statusMessage: 'Test',
        isThinking: true,
        hintMove: 'e2e4',
        lastMove: 'You: e2e4',
        currentBestMove: 'd7d5',
      );

      final updated = state.copyWith(strengthLevel: 8);

      expect(updated.strengthLevel, 8);
      expect(updated.hintDepth, 20);
      expect(updated.showValidMoves, false);
      expect(updated.selectedRow, 3);
      expect(updated.selectedCol, 4);
      expect(updated.statusMessage, 'Test');
      expect(updated.isThinking, true);
      expect(updated.hintMove, 'e2e4');
      expect(updated.lastMove, 'You: e2e4');
      expect(updated.currentBestMove, 'd7d5');
    });

    test('copyWith updates specified fields', () {
      const state = GameState();

      final updated = state.copyWith(
        strengthLevel: 15,
        hintDepth: 25,
        showValidMoves: false,
        animateMoves: false,
        selectedRow: 2,
        selectedCol: 3,
        validMoves: ['e2e4', 'd2d4'],
        statusMessage: 'Thinking...',
        isThinking: true,
        hintMove: 'e2e4',
        lastMove: 'You: e2e4',
        waitingForHint: true,
        analysisExpanded: true,
        currentBestMove: 'd7d5',
      );

      expect(updated.strengthLevel, 15);
      expect(updated.hintDepth, 25);
      expect(updated.showValidMoves, false);
      expect(updated.animateMoves, false);
      expect(updated.selectedRow, 2);
      expect(updated.selectedCol, 3);
      expect(updated.validMoves, ['e2e4', 'd2d4']);
      expect(updated.statusMessage, 'Thinking...');
      expect(updated.isThinking, true);
      expect(updated.hintMove, 'e2e4');
      expect(updated.lastMove, 'You: e2e4');
      expect(updated.waitingForHint, true);
      expect(updated.analysisExpanded, true);
      expect(updated.currentBestMove, 'd7d5');
    });

    test('copyWith can set nullable fields to null', () {
      final state = const GameState(
        selectedRow: 3,
        selectedCol: 4,
        hintMove: 'e2e4',
        currentBestMove: 'd7d5',
      );

      final updated = state.copyWith(
        selectedRow: null,
        selectedCol: null,
        hintMove: null,
        currentBestMove: null,
      );

      expect(updated.selectedRow, isNull);
      expect(updated.selectedCol, isNull);
      expect(updated.hintMove, isNull);
      expect(updated.currentBestMove, isNull);
    });
  });
}
