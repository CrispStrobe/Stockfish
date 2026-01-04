class ChessGame {
  List<String> moveHistory = [];
  String currentFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  
  String get positionCommand {
    if (moveHistory.isEmpty) {
      return 'position startpos';
    }
    return 'position startpos moves ${moveHistory.join(' ')}';
  }
  
  void makeMove(String move) {
    moveHistory.add(move);
  }
  
  void undoMove() {
    if (moveHistory.isNotEmpty) {
      moveHistory.removeLast();
    }
  }
  
  void reset() {
    moveHistory.clear();
    currentFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }
}