import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stockfish/stockfish.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stockfish engine completes UCI handshake', (tester) async {
    final stockfish = Stockfish();

    for (int i = 0; i < 100; i++) {
      if (stockfish.state.value == StockfishState.ready) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    expect(stockfish.state.value, StockfishState.ready);

    // Send UCI and verify response
    final lines = <String>[];
    stockfish.stdout.listen((line) => lines.add(line.trim()));
    stockfish.stdin = 'uci';

    await Future.delayed(const Duration(seconds: 2));
    expect(lines.any((l) => l == 'uciok'), isTrue);

    // Send isready and verify
    stockfish.stdin = 'isready';
    await Future.delayed(const Duration(seconds: 1));
    expect(lines.any((l) => l == 'readyok'), isTrue);

    stockfish.dispose();
  });

  testWidgets('Stockfish engine can analyze a position', (tester) async {
    final stockfish = Stockfish();

    for (int i = 0; i < 100; i++) {
      if (stockfish.state.value == StockfishState.ready) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final lines = <String>[];
    stockfish.stdout.listen((line) => lines.add(line.trim()));

    stockfish.stdin = 'uci';
    await Future.delayed(const Duration(seconds: 1));
    stockfish.stdin = 'isready';
    await Future.delayed(const Duration(seconds: 1));

    stockfish.stdin = 'position startpos';
    stockfish.stdin = 'go depth 5';

    await Future.delayed(const Duration(seconds: 5));

    expect(lines.any((l) => l.startsWith('bestmove')), isTrue);
    expect(lines.any((l) => l.contains('score cp')), isTrue);

    stockfish.dispose();
  });
}
