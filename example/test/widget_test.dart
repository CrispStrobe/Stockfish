import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/main.dart';

void main() {
  testWidgets('App shows CrispChess title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('CrispChess'), findsOneWidget);
  });
}
