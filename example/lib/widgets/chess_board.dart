import 'package:flutter/material.dart';
import '../chess/board_state.dart';

class ChessBoard extends StatelessWidget {
  final BoardState boardState;
  final Function(int fromRow, int fromCol, int toRow, int toCol)? onMove;
  final String? hintMove;
  
  const ChessBoard({
    Key? key,
    required this.boardState,
    this.onMove,
    this.hintMove,
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
    
    return Expanded(
      child: DragTarget<Map<String, int>>(
        onWillAccept: (data) => true,
        onAccept: (data) {
          if (onMove != null) {
            onMove!(data['row']!, data['col']!, row, col);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              color: isHintSquare
                  ? Colors.yellow.withOpacity(0.5)
                  : (isLight ? Colors.brown[200] : Colors.brown[400]),
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
          color: piece.color == PieceColor.white ? Colors.white : Colors.black,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: piece.color == PieceColor.white ? Colors.black : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getUnicodePiece(ChessPiece piece) {
    const white = {
      PieceType.king: '♔',
      PieceType.queen: '♕',
      PieceType.rook: '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn: '♙',
    };
    const black = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };
    return piece.color == PieceColor.white ? white[piece.type]! : black[piece.type]!;
  }
}