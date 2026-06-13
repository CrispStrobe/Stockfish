import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stockfish/stockfish.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stockfish engine initializes', (WidgetTester tester) async {
    final stockfish = Stockfish();
    // Wait for engine to start
    for (int i = 0; i < 50; i++) {
      if (stockfish.state.value == StockfishState.ready) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(stockfish.state.value, StockfishState.ready);
    stockfish.dispose();
  });
}
