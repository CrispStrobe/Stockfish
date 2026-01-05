import 'package:chess/chess.dart' as chess;
import 'move_analyzer.dart';

class ChessGame {
  final chess.Chess _game = chess.Chess();
  final MoveAnalyzer _analyzer;
  final List<MoveAnnotation> _annotations = [];
  
  double? _lastEvaluation;
  String? _lastBestMove;
  
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
  
  /// Update evaluation after Stockfish analysis
  void updateEvaluation(double evaluation, String bestMove, int depth) {
    _lastEvaluation = evaluation;
    _lastBestMove = bestMove;
  }
  
  /// Make a move and annotate it
  bool makeMove(String uciMove) {
    print('--- CHESS LOGIC DEBUG ---');
    print('Checking move: $uciMove');
    print('Current Turn: ${_game.turn == chess.Color.WHITE ? "White" : "Black"}');
    
    if (uciMove.length < 4) return false;
    
    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length > 4 ? uciMove.substring(4, 5) : null;
    
    // Store evaluation before move
    final evalBefore = _lastEvaluation ?? 0.0;
    
    bool success = _game.move({
      'from': from, 
      'to': to, 
      'promotion': promotion
    });
    
    if (success) {
      print('✅ MOVE LEGAL');
      
      // After move is made, we need to request evaluation again
      // The annotation will be completed when new evaluation arrives
      if (_lastEvaluation != null && _lastBestMove != null) {
        final evalAfter = _lastEvaluation!;
        final annotation = _analyzer.analyzeMove(
          uciMove: uciMove,
          evaluation: MoveEvaluation(
            scoreBefore: evalBefore,
            scoreAfter: evalAfter,
            bestMove: _lastBestMove!,
            bestMoveScore: evalAfter,
            depth: 10,
          ),
        );
        _annotations.add(annotation);
      }
      
      // Sync the analyzer's game state using the new method
      _analyzer.syncMove(from, to, promotion);
    } else {
      print('❌ MOVE ILLEGAL!');
      print('-------------------------');
    }
    return success;
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
  }
}