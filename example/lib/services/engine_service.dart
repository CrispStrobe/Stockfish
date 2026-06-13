import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';
import '../chess/engine_controller.dart';
import '../chess/engine_capabilities.dart';

/// Events emitted by the engine service.
sealed class EngineEvent {}

class EvalUpdate extends EngineEvent {
  final double eval;
  final int depth;
  final String bestMove;
  EvalUpdate({required this.eval, required this.depth, required this.bestMove});
}

class BestMoveEvent extends EngineEvent {
  final String move;
  BestMoveEvent(this.move);
}

class StateChangeEvent extends EngineEvent {
  final StockfishState state;
  StateChangeEvent(this.state);
}

class EngineError extends EngineEvent {
  final String message;
  EngineError(this.message);
}

/// Manages the Stockfish engine lifecycle, UCI protocol parsing,
/// and evaluation debouncing. Exposes a clean [events] stream.
class EngineService {
  Stockfish _stockfish;
  late EngineController _controller;

  final _eventController = StreamController<EngineEvent>.broadcast();
  StreamSubscription<String>? _stdoutSubscription;

  // Pre-compiled regex for parsing engine output
  static final _cpRegex = RegExp(r'score cp (-?\d+)');
  static final _depthRegex = RegExp(r'depth (\d+)');
  static final _pvRegex = RegExp(r'pv (\S+)');

  // Debounce state
  Timer? _evalDebounce;
  double? _bufferedEval;
  int _bufferedDepth = 0;
  String? _bufferedBestMove;

  Stream<EngineEvent> get events => _eventController.stream;
  StockfishState get state => _stockfish.state.value;
  EngineCapabilities get capabilities => _controller.capabilities;
  bool get isInitialized => _controller.isInitialized;

  EngineService() : _stockfish = Stockfish() {
    _controller = EngineController(_stockfish);
  }

  /// Initialize the engine: listen for state changes, parse stdout.
  Future<void> initialize() async {
    _stockfish.state.addListener(_onStateChange);
    _listenToStdout();

    // Wait for ready state
    for (int i = 0; i < 100; i++) {
      if (_stockfish.state.value == StockfishState.ready) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_stockfish.state.value != StockfishState.ready) {
      _eventController.add(EngineError('Engine failed to start'));
      return;
    }

    try {
      await _controller.detectCapabilities();
      _eventController.add(StateChangeEvent(StockfishState.ready));
    } catch (e) {
      _eventController.add(EngineError('Failed to detect capabilities: $e'));
    }
  }

  void _onStateChange() {
    _eventController.add(StateChangeEvent(_stockfish.state.value));
  }

  void _listenToStdout() {
    _stdoutSubscription = _stockfish.stdout.listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;

      if (trimmed.startsWith('info') && trimmed.contains('depth')) {
        _parseInfoLine(trimmed);
      } else if (trimmed.startsWith('bestmove')) {
        _parseBestMove(trimmed);
      }
    });
  }

  void _parseInfoLine(String line) {
    final cpMatch = _cpRegex.firstMatch(line);
    final depthMatch = _depthRegex.firstMatch(line);
    final pvMatch = _pvRegex.firstMatch(line);

    if (cpMatch != null && depthMatch != null) {
      _bufferedEval = int.parse(cpMatch.group(1)!) / 100.0;
      _bufferedDepth = int.parse(depthMatch.group(1)!);
      final bm = pvMatch?.group(1) ?? '';
      if (bm.isNotEmpty) _bufferedBestMove = bm;

      _evalDebounce?.cancel();
      _evalDebounce = Timer(const Duration(milliseconds: 200), () {
        if (_bufferedEval != null) {
          _eventController.add(EvalUpdate(
            eval: _bufferedEval!,
            depth: _bufferedDepth,
            bestMove: _bufferedBestMove ?? '',
          ));
        }
      });
    }
  }

  void _parseBestMove(String line) {
    final parts = line.split(' ');
    if (parts.length >= 2 && parts[1] != '(none)') {
      _eventController.add(BestMoveEvent(parts[1]));
    }
  }

  /// Apply strength settings.
  void applyStrength(StrengthSettings settings) {
    _controller.applyStrength(settings);
  }

  /// Request the engine to make a move.
  Future<void> requestMove(
      String positionCommand, StrengthSettings settings) async {
    try {
      await _controller.requestMove(positionCommand, settings);
    } catch (e) {
      _eventController.add(EngineError('Move request failed: $e'));
    }
  }

  /// Request analysis at full strength.
  Future<void> requestAnalysis(String positionCommand, int depth) async {
    try {
      await _controller.requestAnalysis(positionCommand, depth);
    } catch (e) {
      _eventController.add(EngineError('Analysis request failed: $e'));
    }
  }

  /// Stop current engine search.
  void stop() {
    _controller.stop();
  }

  /// Reinitialize the engine after an error.
  Future<void> reinitialize() async {
    dispose();
    _stockfish = Stockfish();
    _controller = EngineController(_stockfish);
    _eventController.add(StateChangeEvent(StockfishState.starting));
    await initialize();
  }

  /// Clean up all resources.
  void dispose() {
    _evalDebounce?.cancel();
    _stdoutSubscription?.cancel();
    _stockfish.state.removeListener(_onStateChange);
    _stockfish.dispose();
  }
}
