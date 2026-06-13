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

    test('canLimitStrength with both skillLevel and uciElo', () {
      final caps = EngineCapabilities()
        ..supportsSkillLevel = true
        ..supportsUciElo = true;
      expect(caps.canLimitStrength, isTrue);
    });

    test('canLimitStrength with neither', () {
      final caps = EngineCapabilities()
        ..supportsSkillLevel = false
        ..supportsUciElo = false;
      expect(caps.canLimitStrength, isFalse);
    });

    test('toString includes all capability info', () {
      final caps = EngineCapabilities()
        ..supportsSkillLevel = true
        ..supportsUciElo = true
        ..supportsUciLimitStrength = true;
      final str = caps.toString();
      expect(str, contains('Skill Level: true'));
      expect(str, contains('UCI_Elo: true'));
      expect(str, contains('UCI_LimitStrength: true'));
    });
  });

  group('StrengthSettings extended', () {
    test('fromLevel level 0 gives minimum values', () {
      final settings = StrengthSettings.fromLevel(0);
      expect(settings.skillLevel, 0);
      expect(settings.targetElo, 800);
      expect(settings.searchDepth, 3);
      expect(settings.moveTime, 0); // default
    });

    test('fromLevel level 20 gives maximum values', () {
      final settings = StrengthSettings.fromLevel(20);
      expect(settings.skillLevel, 20);
      expect(settings.targetElo, 2400);
      expect(settings.searchDepth, 23);
    });

    test('fromLevel clamps ELO correctly', () {
      // Level 0: elo = 800 + (0 * 80).clamp(0, 1600) = 800
      expect(StrengthSettings.fromLevel(0).targetElo, 800);
      // Level 10: elo = 800 + (800).clamp(0, 1600) = 1600
      expect(StrengthSettings.fromLevel(10).targetElo, 1600);
      // Level 20: elo = 800 + (1600).clamp(0, 1600) = 2400
      expect(StrengthSettings.fromLevel(20).targetElo, 2400);
      // Level 25 (beyond range): elo = 800 + (2000).clamp(0, 1600) = 2400
      expect(StrengthSettings.fromLevel(25).targetElo, 2400);
    });

    test('toString includes all settings', () {
      final settings = StrengthSettings.fromLevel(10);
      final str = settings.toString();
      expect(str, contains('level: 10'));
      expect(str, contains('elo: 1600'));
      expect(str, contains('depth: 13'));
    });
  });
}
