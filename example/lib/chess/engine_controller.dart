import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';
import 'engine_capabilities.dart';

class EngineController {
  final Stockfish stockfish;
  EngineCapabilities capabilities = EngineCapabilities();
  bool isInitialized = false;

  EngineController(this.stockfish);

  /// Detect what the engine supports
  Future<void> detectCapabilities() async {
    debugPrint('Detecting engine capabilities...');

    // Listen for UCI options
    final completer = Completer<void>();
    StreamSubscription<String>? subscription;

    try {
      subscription = stockfish.stdout.listen((line) {
        final trimmed = line.trim();

        if (trimmed.startsWith('option name')) {
          _parseOption(trimmed);
        } else if (trimmed == 'uciok') {
          debugPrint('UCI detection complete');
          debugPrint(capabilities.toString());
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Send UCI command to trigger option listing
      stockfish.stdin = 'uci';

      // Timeout after 3 seconds
      await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('UCI detection timed out, using defaults');
        },
      );
    } finally {
      await subscription?.cancel();
    }

    isInitialized = true;
  }

  void _parseOption(String line) {
    // Parse: "option name UCI_Elo type spin default 1320 min 1320 max 3190"
    final nameMatch = RegExp(r'option name (.+?) type').firstMatch(line);
    if (nameMatch == null) return;

    final optionName = nameMatch.group(1)!.trim();
    capabilities.allOptions[optionName] = line;

    switch (optionName) {
      case 'Skill Level':
        capabilities.supportsSkillLevel = true;
        debugPrint('  Found: Skill Level');
        break;

      case 'UCI_Elo':
        capabilities.supportsUciElo = true;
        // Extract min/max values
        final minMatch = RegExp(r'min (\d+)').firstMatch(line);
        final maxMatch = RegExp(r'max (\d+)').firstMatch(line);
        if (minMatch != null) capabilities.minElo = int.parse(minMatch.group(1)!);
        if (maxMatch != null) capabilities.maxElo = int.parse(maxMatch.group(1)!);
        debugPrint('  Found: UCI_Elo (${capabilities.minElo}-${capabilities.maxElo})');
        break;

      case 'UCI_LimitStrength':
        capabilities.supportsUciLimitStrength = true;
        debugPrint('  Found: UCI_LimitStrength');
        break;
    }
  }

  /// Apply strength settings using all available methods
  void applyStrength(StrengthSettings settings) {
    if (!isInitialized) {
      debugPrint('Engine not initialized, cannot apply strength');
      return;
    }

    debugPrint('Applying strength: $settings');

    // Method 1: Skill Level (if supported)
    if (capabilities.supportsSkillLevel) {
      stockfish.stdin = 'setoption name Skill Level value ${settings.skillLevel}';
      debugPrint('  Set Skill Level: ${settings.skillLevel}');
    }

    // Method 2: UCI_Elo (if supported)
    if (capabilities.supportsUciElo && capabilities.supportsUciLimitStrength) {
      stockfish.stdin = 'setoption name UCI_LimitStrength value true';
      final clampedElo = settings.targetElo.clamp(
        capabilities.minElo,
        capabilities.maxElo,
      );
      stockfish.stdin = 'setoption name UCI_Elo value $clampedElo';
      debugPrint('  Set UCI_Elo: $clampedElo');
    }

    // Method 3: Depth limiting (always available) will be applied in go command
    debugPrint('  Will use depth: ${settings.searchDepth}');

    if (!capabilities.canLimitStrength) {
      debugPrint('WARNING: Engine does not support strength limiting!');
      debugPrint('   Only depth limiting will be used.');
    }
  }

  /// Wait for the engine to signal readiness via 'readyok'.
  Future<void> waitForReady({Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<void>();
    StreamSubscription<String>? subscription;

    try {
      subscription = stockfish.stdout.listen((line) {
        if (line.trim() == 'readyok' && !completer.isCompleted) {
          completer.complete();
        }
      });

      stockfish.stdin = 'isready';

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('waitForReady timed out after ${timeout.inSeconds}s');
        },
      );
    } finally {
      await subscription?.cancel();
    }
  }

  /// Request move with strength settings applied.
  /// A 30-second safety timer calls stop() if no bestmove arrives.
  Future<void> requestMove(String positionCommand, StrengthSettings settings, {Duration moveTimeout = const Duration(seconds: 30)}) async {
    await waitForReady();
    stockfish.stdin = positionCommand;
    stockfish.stdin = 'go depth ${settings.searchDepth}';

    // Safety timer: abort if bestmove never arrives
    Timer(moveTimeout, () {
      debugPrint('Move timeout after ${moveTimeout.inSeconds}s, sending stop');
      stop();
    });
  }

  /// Send stop command to abort current search
  void stop() {
    stockfish.stdin = 'stop';
  }

  /// Request analysis at full strength.
  Future<void> requestAnalysis(String positionCommand, int depth) async {
    // Temporarily disable strength limits for analysis
    if (capabilities.supportsSkillLevel) {
      stockfish.stdin = 'setoption name Skill Level value 20';
    }
    if (capabilities.supportsUciElo && capabilities.supportsUciLimitStrength) {
      stockfish.stdin = 'setoption name UCI_LimitStrength value false';
    }

    await waitForReady();
    stockfish.stdin = positionCommand;
    stockfish.stdin = 'go depth $depth';
  }
}
