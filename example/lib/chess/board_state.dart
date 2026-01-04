enum PieceType { pawn, knight, bishop, rook, queen, king }
enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  
  ChessPiece(this.type, this.color);
  
  String get symbol {
    final symbols = {
      PieceType.pawn: 'p',
      PieceType.knight: 'n',
      PieceType.bishop: 'b',
      PieceType.rook: 'r',
      PieceType.queen: 'q',
      PieceType.king: 'k',
    };
    final s = symbols[type]!;
    return color == PieceColor.white ? s.toUpperCase() : s;
  }
}

class BoardState {
  // 8x8 board, null means empty square
  List<List<ChessPiece?>> board = List.generate(8, (_) => List.filled(8, null));
  bool whiteToMove = true;
  
  BoardState() {
    _setupInitialPosition();
  }
  
  void _setupInitialPosition() {
    // Pawns
    for (int i = 0; i < 8; i++) {
      board[1][i] = ChessPiece(PieceType.pawn, PieceColor.black);
      board[6][i] = ChessPiece(PieceType.pawn, PieceColor.white);
    }
    
    // Black pieces
    board[0][0] = ChessPiece(PieceType.rook, PieceColor.black);
    board[0][1] = ChessPiece(PieceType.knight, PieceColor.black);
    board[0][2] = ChessPiece(PieceType.bishop, PieceColor.black);
    board[0][3] = ChessPiece(PieceType.queen, PieceColor.black);
    board[0][4] = ChessPiece(PieceType.king, PieceColor.black);
    board[0][5] = ChessPiece(PieceType.bishop, PieceColor.black);
    board[0][6] = ChessPiece(PieceType.knight, PieceColor.black);
    board[0][7] = ChessPiece(PieceType.rook, PieceColor.black);
    
    // White pieces
    board[7][0] = ChessPiece(PieceType.rook, PieceColor.white);
    board[7][1] = ChessPiece(PieceType.knight, PieceColor.white);
    board[7][2] = ChessPiece(PieceType.bishop, PieceColor.white);
    board[7][3] = ChessPiece(PieceType.queen, PieceColor.white);
    board[7][4] = ChessPiece(PieceType.king, PieceColor.white);
    board[7][5] = ChessPiece(PieceType.bishop, PieceColor.white);
    board[7][6] = ChessPiece(PieceType.knight, PieceColor.white);
    board[7][7] = ChessPiece(PieceType.rook, PieceColor.white);
  }
  
  String squareToAlgebraic(int row, int col) {
    return '${String.fromCharCode(97 + col)}${8 - row}';
  }
  
  void makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = board[fromRow][fromCol];
    if (piece == null) return;

    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;
    
    // Switch turn
    whiteToMove = (piece.color == PieceColor.black); 
  }
  
  void reset() {
    board = List.generate(8, (_) => List.filled(8, null));
    whiteToMove = true;
    _setupInitialPosition();
  }
}