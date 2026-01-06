import 'package:chess/chess.dart' as chess;
import 'move_analyzer.dart';

class ChessGame {
  final chess.Chess _game = chess.Chess();
  final MoveAnalyzer _analyzer;
  final List<MoveAnnotation> _annotations = [];
  
  double? _lastEvaluation;
  String? _lastBestMove;
  int? _lastDepth;
  
  // Initialize with a separate Chess instance for the analyzer
  ChessGame() : _analyzer = MoveAnalyzer(chess.Chess());
  
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
    final moves = _game.generate_moves();
    return moves.map((m) => '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ""}').toList();
  }
  
  /// Update evaluation from Stockfish
  void updateEvaluation(double evaluation, String bestMove, int depth) {
    _lastEvaluation = evaluation;
    _lastBestMove = bestMove;
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
  print('--- MAKING MOVE: $uciMove ---');
  print('Current turn: ${_game.turn == chess.Color.WHITE ? "White" : "Black"}');
  print('Evaluation before move: $_lastEvaluation');
  
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
    print('✅ Move successful');
    
    // Sync the analyzer's game state
    _analyzer.syncMove(from, to, promotion);
    
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
    print('📝 Created incomplete annotation (will complete when eval arrives)');
  } else {
    print('❌ Move failed');
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
  
  print('✅ Completed annotation for ${incomplete.move}: ${completeEval.quality} (change: ${completeEval.evaluationChange.toStringAsFixed(2)})');
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
    _game.undo();
    _analyzer.syncUndo();
    if (_annotations.isNotEmpty) {
      _annotations.removeLast();
    }
  }
  
  void reset() {
    _game.reset();
    _analyzer.syncReset();
    _annotations.clear();
    _lastEvaluation = null;
    _lastBestMove = null;
    _lastDepth = null;
  }
}