import 'package:flutter/material.dart';
import '../chess/board_state.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChessBoard extends StatefulWidget {
  final BoardState boardState;
  final Function(int fromRow, int fromCol, int toRow, int toCol)? onMove;
  final Function(int row, int col)? onSquareTap;
  final int? selectedRow;
  final int? selectedCol;
  final List<String> validMoves;
  final String? hintMove;
  final bool isCheck;
  final bool animateMoves;
  
  const ChessBoard({
    Key? key,
    required this.boardState,
    this.onMove,
    this.onSquareTap,
    this.selectedRow,
    this.selectedCol,
    this.validMoves = const [],
    this.hintMove,
    this.isCheck = false,
    this.animateMoves = true,
  }) : super(key: key);
  
  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<Offset>? _animation;
  String? _animatingMove;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  void _animateMove(int fromRow, int fromCol, int toRow, int toCol) {
    if (!widget.animateMoves) return;
    
    final dx = (toCol - fromCol).toDouble();
    final dy = (toRow - fromRow).toDouble();
    
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(dx, dy),
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    
    _animatingMove = '${fromRow}_${fromCol}';
    _animationController!.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _animatingMove = null;
        });
      }
    });
  }
  
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
    final piece = widget.boardState.board[row][col];
    final square = widget.boardState.squareToAlgebraic(row, col);
    
    // Check if selected
    final isSelected = widget.selectedRow == row && widget.selectedCol == col;
    
    // Check if valid move target
    final isValidTarget = widget.validMoves.any((move) {
      if (move.length < 4) return false;
      final targetSquare = move.substring(2, 4);
      return targetSquare == square;
    });
    
    // Check if hint square
    bool isHintSquare = false;
    if (widget.hintMove != null && widget.hintMove!.length >= 4) {
      final from = widget.hintMove!.substring(0, 2);
      final to = widget.hintMove!.substring(2, 4);
      isHintSquare = square == from || square == to;
    }

    // Check if king in danger
    bool isKingInDanger = false;
    if (widget.isCheck && piece != null && piece.type == PieceType.king) {
      if (widget.boardState.whiteToMove && piece.color == PieceColor.white) {
        isKingInDanger = true;
      }
      if (!widget.boardState.whiteToMove && piece.color == PieceColor.black) {
        isKingInDanger = true;
      }
    }
    
    // Check if animating
    final isAnimating = _animatingMove == '${row}_$col';
    
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onSquareTap?.call(row, col),
        child: DragTarget<Map<String, int>>(
          onWillAccept: (data) => true,
          onAccept: (data) {
            if (widget.onMove != null) {
              _animateMove(data['row']!, data['col']!, row, col);
              widget.onMove!(data['row']!, data['col']!, row, col);
            }
          },
          builder: (context, candidateData, rejectedData) {
            Color? bgColor;
            if (isKingInDanger) {
              bgColor = Colors.red.withOpacity(0.7);
            } else if (isSelected) {
              bgColor = Colors.blue.withOpacity(0.5);
            } else if (isValidTarget) {
              bgColor = isLight 
                ? Colors.green.withOpacity(0.3) 
                : Colors.green.withOpacity(0.4);
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
                    : isSelected
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
              ),
              child: Stack(
                children: [
                  // Square label
                  if (piece == null)
                    Center(
                      child: Text(
                        square,
                        style: TextStyle(
                          fontSize: 8,
                          color: isLight ? Colors.brown[400] : Colors.brown[200],
                        ),
                      ),
                    ),
                  
                  // Valid move indicator
                  if (isValidTarget && piece == null)
                    Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  
                  // Piece
                  if (piece != null)
                    isAnimating && _animation != null
                        ? AnimatedBuilder(
                            animation: _animation!,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _animation!.value.dx * MediaQuery.of(context).size.width / 8,
                                  _animation!.value.dy * MediaQuery.of(context).size.height / 8,
                                ),
                                child: child,
                              );
                            },
                            child: _PieceWidget(piece: piece),
                          )
                        : Draggable<Map<String, int>>(
                            data: {'row': row, 'col': col},
                            feedback: _PieceWidget(piece: piece, size: 60),
                            childWhenDragging: Container(),
                            child: _PieceWidget(piece: piece),
                          ),
                ],
              ),
            );
          },
        ),
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
      child: SvgPicture.asset(
        _getPieceAsset(piece),
        width: size ?? 45,
        height: size ?? 45,
      ),
    );
  }
  
  String _getPieceAsset(ChessPiece piece) {
    final colorPrefix = piece.color == PieceColor.white ? 'w' : 'b';
    
    String typeSuffix = '';
    switch (piece.type) {
      case PieceType.pawn:   typeSuffix = 'P'; break;
      case PieceType.knight: typeSuffix = 'N'; break;
      case PieceType.bishop: typeSuffix = 'B'; break;
      case PieceType.rook:   typeSuffix = 'R'; break;
      case PieceType.queen:  typeSuffix = 'Q'; break;
      case PieceType.king:   typeSuffix = 'K'; break;
    }
    
    return 'assets/pieces/$colorPrefix$typeSuffix.svg';
  }
}