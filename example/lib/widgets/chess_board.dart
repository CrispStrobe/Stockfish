import 'package:flutter/material.dart';
import '../chess/board_state.dart';

class ChessBoard extends StatelessWidget {
  final BoardState boardState;
  final Function(int fromRow, int fromCol, int toRow, int toCol)? onMove;
  final String? hintMove;
  final bool isCheck;
  
  const ChessBoard({
    Key? key,
    required this.boardState,
    this.onMove,
    this.hintMove,
    this.isCheck = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown, width: 2),
        ),
        child: Column(
          children: List.generate(8, (row) {
            return Expanded(
              child: Row(
                children: List.generate(8, (col) {
                  return _buildSquare(row, col);
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildSquare(int row, int col) {
    final isLight = (row + col) % 2 == 0;
    final piece = boardState.board[row][col];
    final square = boardState.squareToAlgebraic(row, col);
    
    // Check if this square is part of hint move
    bool isHintSquare = false;
    if (hintMove != null && hintMove!.length >= 4) {
      final from = hintMove!.substring(0, 2);
      final to = hintMove!.substring(2, 4);
      isHintSquare = square == from || square == to;
    }

    // Check if this square holds the King that is currently in Check
    bool isKingInDanger = false;
    if (isCheck && piece != null && piece.type == PieceType.king) {
        // If it's white's turn and I am the white king -> I am in danger
        if (boardState.whiteToMove && piece.color == PieceColor.white) isKingInDanger = true;
        // If it's black's turn and I am the black king -> I am in danger
        if (!boardState.whiteToMove && piece.color == PieceColor.black) isKingInDanger = true;
    }
    
    return Expanded(
      child: DragTarget<Map<String, int>>(
        onWillAccept: (data) => true,
        onAccept: (data) {
          if (onMove != null) {
            onMove!(data['row']!, data['col']!, row, col);
          }
        },
        builder: (context, candidateData, rejectedData) {
          
          // Determine Background Color
          Color? bgColor;
          if (isKingInDanger) {
             bgColor = Colors.red.withOpacity(0.8); // DANGER COLOR
          } else if (isHintSquare) {
             bgColor = Colors.yellow.withOpacity(0.5);
          } else {
             bgColor = isLight ? Colors.brown[200] : Colors.brown[400];
          }
          
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: candidateData.isNotEmpty
                  ? Border.all(color: Colors.green, width: 3)
                  : null,
            ),
            child: piece == null
                ? Center(
                    child: Text(
                      square,
                      style: TextStyle(
                        fontSize: 8,
                        color: isLight ? Colors.brown[400] : Colors.brown[200],
                      ),
                    ),
                  )
                : Draggable<Map<String, int>>(
                    data: {'row': row, 'col': col},
                    feedback: _PieceWidget(piece: piece, size: 60),
                    childWhenDragging: Container(),
                    child: _PieceWidget(piece: piece),
                  ),
          );
        },
      ),
    );
  }
}

class _PieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final double? size;
  
  const _PieceWidget({required this.piece, this.size});
  
  @override
  Widget build(BuildContext context) {
  return Center(
    child: Text(
      _getUnicodePiece(piece),
      style: TextStyle(
        fontSize: size ?? 40,
        // Both white and black pieces use black color now
        // White pieces are naturally outlined, black are filled
        color: Colors.black,
        shadows: const [
          Shadow(
            offset: Offset(0, 0),
            blurRadius: 1,
            color: Colors.black26,
          ),
        ],
      ),
    ),
  );
}
  
  String _getUnicodePiece(ChessPiece piece) {
  // Use FILLED symbols for black, OUTLINED for white
  final blackSymbols = {
    PieceType.king: '♚',
    PieceType.queen: '♛',
    PieceType.rook: '♜',
    PieceType.bishop: '♝',
    PieceType.knight: '♞',
    PieceType.pawn: '♟',
  };
  
  final whiteSymbols = {
    PieceType.king: '♔',
    PieceType.queen: '♕',
    PieceType.rook: '♖',
    PieceType.bishop: '♗',
    PieceType.knight: '♘',
    PieceType.pawn: '♙',
  };
  
  final symbols = piece.color == PieceColor.white ? whiteSymbols : blackSymbols;
  
  // Append '\uFE0E' to force text rendering
  return symbols[piece.type]! + '\uFE0E';
}



}