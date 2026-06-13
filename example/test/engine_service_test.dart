import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish/stockfish.dart';
import 'package:stockfish_example/services/engine_service.dart';

void main() {
  group('EngineEvent types', () {
    test('EvalUpdate holds evaluation data', () {
      final event = EvalUpdate(eval: 1.5, depth: 20, bestMove: 'e2e4');
      expect(event.eval, 1.5);
      expect(event.depth, 20);
      expect(event.bestMove, 'e2e4');
    });

    test('BestMoveEvent holds move string', () {
      final event = BestMoveEvent('d2d4');
      expect(event.move, 'd2d4');
    });

    test('EngineError holds message', () {
      final event = EngineError('timeout');
      expect(event.message, 'timeout');
    });

    test('EngineEvent sealed class switch is exhaustive', () {
      final EngineEvent event = BestMoveEvent('e2e4');
      final result = switch (event) {
        EvalUpdate() => 'eval',
        BestMoveEvent() => 'best',
        StateChangeEvent() => 'state',
        EngineError() => 'error',
      };
      expect(result, 'best');
    });
  });

  group('EngineService stream mechanics', () {
    test('broadcast stream allows multiple listeners', () async {
      final controller = StreamController<EngineEvent>.broadcast();
      int count1 = 0;
      int count2 = 0;

      controller.stream.listen((_) => count1++);
      controller.stream.listen((_) => count2++);

      controller.add(BestMoveEvent('e2e4'));
      await Future.delayed(Duration.zero);

      expect(count1, 1);
      expect(count2, 1);

      await controller.close();
    });

    test('EvalUpdate debounce pattern works', () async {
      final controller = StreamController<EngineEvent>.broadcast();
      final events = <EngineEvent>[];
      controller.stream.listen(events.add);

      // Simulate rapid eval updates with debounce
      Timer? debounce;
      double? buffered;
      for (int i = 0; i < 10; i++) {
        buffered = i * 0.1;
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 50), () {
          controller.add(EvalUpdate(eval: buffered!, depth: 10, bestMove: 'e2e4'));
        });
      }

      // Wait for debounce to settle
      await Future.delayed(const Duration(milliseconds: 100));

      // Only one event should have fired (the last debounce)
      expect(events.length, 1);
      expect((events.first as EvalUpdate).eval, closeTo(0.9, 0.01));

      debounce?.cancel();
      await controller.close();
    });
  });

  group('EngineEvent pattern matching', () {
    test('EngineEvent pattern matching covers all subtypes', () {
      final events = <EngineEvent>[
        EvalUpdate(eval: 0.5, depth: 10, bestMove: 'e2e4'),
        BestMoveEvent('d2d4'),
        StateChangeEvent(StockfishState.ready),
        EngineError('test error'),
      ];

      final results = events.map((event) {
        return switch (event) {
          EvalUpdate() => 'eval',
          BestMoveEvent() => 'best',
          StateChangeEvent() => 'state',
          EngineError() => 'error',
        };
      }).toList();

      expect(results, ['eval', 'best', 'state', 'error']);
    });
  });

  group('StateChangeEvent', () {
    test('StateChangeEvent holds correct state', () {
      final event = StateChangeEvent(StockfishState.ready);
      expect(event.state, StockfishState.ready);

      final starting = StateChangeEvent(StockfishState.starting);
      expect(starting.state, StockfishState.starting);

      final error = StateChangeEvent(StockfishState.error);
      expect(error.state, StockfishState.error);

      final disposed = StateChangeEvent(StockfishState.disposed);
      expect(disposed.state, StockfishState.disposed);
    });
  });

  group('Debounce behavior', () {
    test('multiple rapid EvalUpdates debounce to one', () async {
      final controller = StreamController<EngineEvent>.broadcast();
      final events = <EngineEvent>[];
      controller.stream.listen(events.add);

      // Simulate 50 rapid eval updates, each canceling the previous debounce
      Timer? debounce;
      double? buffered;
      int bufferedDepth = 0;
      for (int i = 0; i < 50; i++) {
        buffered = i * 0.02;
        bufferedDepth = i + 1;
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 50), () {
          controller.add(EvalUpdate(
            eval: buffered!,
            depth: bufferedDepth,
            bestMove: 'e2e4',
          ));
        });
      }

      // Wait for debounce to settle
      await Future.delayed(const Duration(milliseconds: 150));

      // Only the last event should have fired
      expect(events.length, 1);
      final update = events.first as EvalUpdate;
      expect(update.eval, closeTo(0.98, 0.01));
      expect(update.depth, 50);

      debounce?.cancel();
      await controller.close();
    });
  });
}
