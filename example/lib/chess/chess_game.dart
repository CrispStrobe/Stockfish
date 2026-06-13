import 'package:chess/chess.dart' as chess;
import 'package:flutter/foundation.dart';
import 'move_analyzer.dart';

class ChessGame with ChangeNotifier {
  final chess.Chess _game = chess.Chess();
  late final MoveAnalyzer _analyzer;
  final List<MoveAnnotation> _annotations = [];

  List<String>? _cachedLegalMoves;

  double? _lastEvaluation;
  int? _lastDepth;

  ChessGame() {
    _analyzer = MoveAnalyzer(_game);
  }
  
  bool get inCheck => _game.in_check;
  String get currentFEN => _game.fen;
  
  List<String> get moveHistory => _game.history
      .map((m) => '${m.move.fromAlgebraic}${m.move.toAlgebraic}${m.move.promotion?.name ?? ""}')
      .toList();
  
  List<MoveAnnotation> get annotations => _annotations;
  MoveAnnotation? get lastAnnotation => _annotations.isEmpty ? null : _annotations.last;
  
  String get positionCommand {
    final cmd = moveHistory.isEmpty 
        ? 'position startpos' 
        : 'position startpos moves ${moveHistory.join(' ')}';
    return cmd;
  }
  
  List<String> getLegalMoves() {
    _cachedLegalMoves ??= _game.generate_moves()
        .map((m) => '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ""}')
        .toList();
    return _cachedLegalMoves!;
  }
  
  /// Update evaluation from Stockfish
  void updateEvaluation(double evaluation, String bestMove, int depth) {
    _lastEvaluation = evaluation;
    _lastDepth = depth;
    
    // If we have a pending annotation without complete evaluation, update it
    if (_annotations.isNotEmpty) {
      final last = _annotations.last;
      // Check if this is an incomplete annotation (has scoreBefore but scoreAfter is 0)
      if (last.evaluation.scoreBefore != 0.0 && 
          last.evaluation.scoreAfter == 0.0 && 
          last.evaluation.bestMove.isEmpty) {
        _completeLastAnnotation(evaluation, bestMove, depth);
      }
    }
  }
  
  
  /// Make a move and create initial annotation
  bool makeMove(String uciMove) {
  if (uciMove.length < 4) return false;
  
  final from = uciMove.substring(0, 2);
  final to = uciMove.substring(2, 4);
  final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;
  
  // Store evaluation BEFORE making the move AND whose turn it is
  final evalBefore = _lastEvaluation ?? 0.0;
  final whiteToMove = _game.turn == chess.Color.WHITE;  // ADD THIS
  
  // Make the move in the main game
  bool success = _game.move({
    'from': from, 
    'to': to, 
    'promotion': promotion
  });
  
  if (success) {
    _cachedLegalMoves = null;

    // Create INCOMPLETE annotation with temporary evaluation
    final tempEval = MoveEvaluation(
      scoreBefore: evalBefore,
      scoreAfter: 0.0,
      bestMove: '',
      bestMoveScore: 0.0,
      depth: _lastDepth ?? 10,
      whiteToMove: whiteToMove,  // ADD THIS
    );
    
    final annotation = _analyzer.analyzeMove(
      uciMove: uciMove,
      evaluation: tempEval,
    );
    
    _annotations.add(annotation);
    notifyListeners();
  }

  return success;
}

void _completeLastAnnotation(double evalAfter, String bestMove, int depth) {
  if (_annotations.isEmpty) return;
  
  final incomplete = _annotations.last;
  final evalBefore = incomplete.evaluation.scoreBefore;
  final whiteToMove = incomplete.evaluation.whiteToMove;  // GET THIS
  
  // Create complete MoveEvaluation
  final completeEval = MoveEvaluation(
    scoreBefore: evalBefore,
    scoreAfter: evalAfter,
    bestMove: bestMove,
    bestMoveScore: evalAfter,
    depth: depth,
    whiteToMove: whiteToMove,  // ADD THIS
  );
  
  // Re-analyze with complete evaluation
  final completeAnnotation = _analyzer.analyzeMove(
    uciMove: incomplete.move,
    evaluation: completeEval,
  );
  
  _annotations[_annotations.length - 1] = completeAnnotation;
}
  
  bool get isGameOver => _game.game_over;
  
  String get gameOverReason {
    if (_game.in_checkmate) return 'Checkmate!';
    if (_game.in_draw) return 'Draw';
    if (_game.in_stalemate) return 'Stalemate!';
    if (_game.in_threefold_repetition) return 'Threefold Repetition!';
    return 'Game Over';
  }
  
  String? get winner {
    if (!_game.in_checkmate) return null;
    return _game.turn == chess.Color.WHITE ? 'Black' : 'White';
  }
  
  void undoMove() {
    _cachedLegalMoves = null;
    _game.undo();
    if (_annotations.isNotEmpty) {
      _annotations.removeLast();
    }
    notifyListeners();
  }
  
  void reset() {
    _cachedLegalMoves = null;
    _game.reset();
    _annotations.clear();
    _lastEvaluation = null;
    _lastDepth = null;
    notifyListeners();
  }
}