import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/board_state.dart';
import 'package:stockfish_example/widgets/chess_board.dart';

void main() {
  testWidgets('ChessBoard renders 64 squares', (tester) async {
    final boardState = BoardState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChessBoard(
          boardState: boardState,
        ),
      ),
    ));
    // There should be 64 GestureDetector widgets (one per square)
    expect(find.byType(GestureDetector), findsNWidgets(64));
  });
}
