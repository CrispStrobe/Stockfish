import 'package:chess/chess.dart' as chess;

enum MoveQuality {
  excellent,  // Best or near-best move
  good,       // Solid move
  inaccuracy, // Small mistake
  mistake,    // Clear error
  blunder,    // Major error
}

class MoveAnnotation {
  final String move;
  final double? evaluationBefore;
  final double? evaluationAfter;
  final MoveQuality? quality;
  
  MoveAnnotation({
    required this.move,
    this.evaluationBefore,
    this.evaluationAfter,
    this.quality,
  });
  
  double? get centipawnLoss {
    if (evaluationBefore == null || evaluationAfter == null) return null;
    return (evaluationBefore! - evaluationAfter!).abs();
  }
  
  String get qualitySymbol {
    if (quality == null) return '';
    switch (quality!) {
      case MoveQuality.excellent: return '!!';
      case MoveQuality.good: return '!';
      case MoveQuality.inaccuracy: return '?!';
      case MoveQuality.mistake: return '?';
      case MoveQuality.blunder: return '??';
    }
  }
  
  String getFullDescription() {
    final parts = <String>[];
    
    if (quality != null) {
      parts.add('${qualitySymbol} ${_getQualityText()}');
    }
    
    if (centipawnLoss != null && centipawnLoss! > 0.3) {
      parts.add('Evaluation change: ${centipawnLoss!.toStringAsFixed(1)} pawns');
    }
    
    if (evaluationAfter != null) {
      final eval = evaluationAfter!;
      if (eval > 2.0) {
        parts.add('White has a winning advantage');
      } else if (eval > 1.0) {
        parts.add('White is better');
      } else if (eval > 0.3) {
        parts.add('White is slightly better');
      } else if (eval < -2.0) {
        parts.add('Black has a winning advantage');
      } else if (eval < -1.0) {
        parts.add('Black is better');
      } else if (eval < -0.3) {
        parts.add('Black is slightly better');
      } else {
        parts.add('Position is equal');
      }
    }
    
    return parts.isEmpty ? 'Move played' : parts.join('\n');
  }
  
  String _getQualityText() {
    switch (quality!) {
      case MoveQuality.excellent: return 'Excellent move!';
      case MoveQuality.good: return 'Good move';
      case MoveQuality.inaccuracy: return 'Inaccuracy';
      case MoveQuality.mistake: return 'Mistake';
      case MoveQuality.blunder: return 'Blunder!';
    }
  }
}

class ChessGame {
  final chess.Chess _game = chess.Chess();
  final List<MoveAnnotation> _annotations = [];
  
  double? _lastEvaluation;
  String? _lastBestMove;
  
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
  
  void updateEvaluation(double evaluation, String bestMove, int depth) {
    _lastEvaluation = evaluation;
    _lastBestMove = bestMove;
  }
  
  bool makeMove(String uciMove) {
    if (uciMove.length < 4) return false;
    
    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;
    
    final evalBefore = _lastEvaluation;
    
    bool success = _game.move({
      'from': from, 
      'to': to, 
      'promotion': promotion
    });
    
    if (success && evalBefore != null) {
      // Create annotation with evaluation before
      // Evaluation after will be updated later
      _annotations.add(MoveAnnotation(
        move: uciMove,
        evaluationBefore: evalBefore,
      ));
    }
    
    return success;
  }
  
  void updateLastAnnotation(double evalAfter) {
    if (_annotations.isEmpty) return;
    
    final last = _annotations.last;
    if (last.evaluationBefore == null) return;
    
    // Calculate quality based on centipawn loss
    MoveQuality quality;
    final loss = (last.evaluationBefore! - evalAfter).abs();
    
    if (loss < 0.3) {
      quality = MoveQuality.excellent;
    } else if (loss < 0.7) {
      quality = MoveQuality.good;
    } else if (loss < 1.5) {
      quality = MoveQuality.inaccuracy;
    } else if (loss < 3.0) {
      quality = MoveQuality.mistake;
    } else {
      quality = MoveQuality.blunder;
    }
    
    // Replace with updated annotation
    _annotations[_annotations.length - 1] = MoveAnnotation(
      move: last.move,
      evaluationBefore: last.evaluationBefore,
      evaluationAfter: evalAfter,
      quality: quality,
    );
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
    if (_annotations.isNotEmpty) {
      _annotations.removeLast();
    }
  }

  List<String> getLegalMoves() {
    final moves = _game.generate_moves();
    return moves.map((m) => '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ""}').toList();
    }
  
  void reset() {
    _game.reset();
    _annotations.clear();
    _lastEvaluation = null;
    _lastBestMove = null;
  }
}