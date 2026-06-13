import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish_example/chess/engine_capabilities.dart';

void main() {
  group('Completer with timeout', () {
    test('completes normally before timeout', () async {
      final completer = Completer<void>();

      // Complete after 50ms
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!completer.isCompleted) completer.complete();
      });

      // Should not throw
      await completer.future.timeout(const Duration(seconds: 1));
    });

    test('timeout fires when completer never completes', () async {
      final completer = Completer<void>();
      var timedOut = false;

      await completer.future.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () {
          timedOut = true;
        },
      );

      expect(timedOut, isTrue);
    });
  });

  group('StrengthSettings', () {
    test('fromLevel(0) produces minimum values', () {
      final settings = StrengthSettings.fromLevel(0);
      expect(settings.skillLevel, 0);
      expect(settings.targetElo, 800);
      expect(settings.searchDepth, 3);
    });

    test('fromLevel(10) produces mid values', () {
      final settings = StrengthSettings.fromLevel(10);
      expect(settings.skillLevel, 10);
      expect(settings.targetElo, 1600);
      expect(settings.searchDepth, 13);
    });

    test('fromLevel(20) produces max values', () {
      final settings = StrengthSettings.fromLevel(20);
      expect(settings.skillLevel, 20);
      expect(settings.targetElo, 2400);
      expect(settings.searchDepth, 23);
    });
  });

  group('EngineCapabilities', () {
    test('canLimitStrength is false by default', () {
      final caps = EngineCapabilities();
      expect(caps.canLimitStrength, isFalse);
    });

    test('canLimitStrength is true when skillLevel supported', () {
      final caps = EngineCapabilities()..supportsSkillLevel = true;
      expect(caps.canLimitStrength, isTrue);
    });

    test('canLimitStrength is true when uciElo supported', () {
      final caps = EngineCapabilities()..supportsUciElo = true;
      expect(caps.canLimitStrength, isTrue);
    });

    test('default elo range', () {
      final caps = EngineCapabilities();
      expect(caps.minElo, 1320);
      expect(caps.maxElo, 3190);
    });
  });
}
