import 'package:flutter/material.dart';
import 'package:stockfish/stockfish.dart';
import '../chess/board_state.dart';
import '../chess/chess_game.dart';
import '../widgets/chess_board.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({Key? key}) : super(key: key);
  
  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  late Stockfish stockfish;
  late BoardState boardState;
  late ChessGame game;
  
  List<String> engineOutput = [];
  String? hintMove;
  int skillLevel = 10;
  bool thinking = false;
  String statusMessage = 'Initializing...';
  
  @override
  void initState() {
    super.initState();
    
    try {
      stockfish = Stockfish();
      boardState = BoardState();
      game = ChessGame();
      
      // Listen to Stockfish output
      stockfish.stdout.listen(
        (line) {
          debugPrint('Stockfish: $line');
          setState(() {
            engineOutput.insert(0, line);
            if (engineOutput.length > 100) engineOutput.removeLast();
          });
          
          // Parse best move
          if (line.startsWith('bestmove')) {
            final parts = line.split(' ');
            if (parts.length >= 2) {
              _makeEngineMove(parts[1]);
            }
          }
        },
        onError: (error) {
          debugPrint('Stockfish error: $error');
          setState(() => statusMessage = 'Error: $error');
        },
      );
      
      // Initialize engine
      Future.delayed(Duration(milliseconds: 500), () {
        try {
          _sendCommand('setoption name Threads value 1');
          _sendCommand('setoption name Skill Level value $skillLevel');
          setState(() => statusMessage = 'Ready - White to move');
        } catch (e) {
          debugPrint('Init error: $e');
          setState(() => statusMessage = 'Init error: $e');
        }
      });
    } catch (e) {
      debugPrint('Fatal error in initState: $e');
      setState(() => statusMessage = 'Fatal error: $e');
    }
  }
  
  void _sendCommand(String cmd) {
    try {
      debugPrint('Sending command: $cmd');
      if (stockfish.state.value == StockfishState.ready) {
        stockfish.stdin = cmd;
      } else {
        debugPrint('Stockfish not ready: ${stockfish.state.value}');
      }
    } catch (e) {
      debugPrint('Error sending command: $e');
      setState(() => statusMessage = 'Command error: $e');
    }
  }
  
  void _makeEngineMove(String move) {
    try {
      debugPrint('Engine move: $move');
      if (move.length >= 4) {
        final fromSquare = move.substring(0, 2);
        final toSquare = move.substring(2, 4);
        
        final fromCol = fromSquare.codeUnitAt(0) - 97;
        final fromRow = 8 - int.parse(fromSquare[1]);
        final toCol = toSquare.codeUnitAt(0) - 97;
        final toRow = 8 - int.parse(toSquare[1]);
        
        setState(() {
          boardState.makeMove(fromRow, fromCol, toRow, toCol);
          game.makeMove(move);
          thinking = false;
          statusMessage = boardState.whiteToMove ? 'White to move' : 'Black to move';
        });
      }
    } catch (e) {
      debugPrint('Error making engine move: $e');
      setState(() {
        thinking = false;
        statusMessage = 'Engine move error: $e';
      });
    }
  }
  
  void _onMove(int fromRow, int fromCol, int toRow, int toCol) {
    try {
      debugPrint('Move attempt: ($fromRow,$fromCol) -> ($toRow,$toCol)');
      
      final piece = boardState.board[fromRow][fromCol];
      if (piece == null) {
        debugPrint('No piece at source');
        return;
      }
      
      final isWhitePiece = piece.color == PieceColor.white;
      if (isWhitePiece != boardState.whiteToMove) {
        setState(() => statusMessage = 'Not your turn!');
        return;
      }
      
      final move = boardState.squareToAlgebraic(fromRow, fromCol) +
          boardState.squareToAlgebraic(toRow, toCol);
      
      debugPrint('Making move: $move');
      
      setState(() {
        boardState.makeMove(fromRow, fromCol, toRow, toCol);
        game.makeMove(move);
        hintMove = null;
        statusMessage = 'Thinking...';
      });
      
      // Engine's turn
      _requestEngineMove();
    } catch (e) {
      debugPrint('Error in onMove: $e');
      setState(() => statusMessage = 'Move error: $e');
    }
  }
  
  void _requestEngineMove() {
    try {
      setState(() => thinking = true);
      _sendCommand(game.positionCommand);
      _sendCommand('go depth ${20 - skillLevel}');
    } catch (e) {
      debugPrint('Error requesting engine move: $e');
      setState(() {
        thinking = false;
        statusMessage = 'Engine request error: $e';
      });
    }
  }
  
  void _requestHint() {
    try {
      _sendCommand(game.positionCommand);
      _sendCommand('go depth 10');
    } catch (e) {
      debugPrint('Error requesting hint: $e');
    }
  }
  
  void _undo() {
    try {
      if (game.moveHistory.length >= 2) {
        setState(() {
          game.undoMove();
          game.undoMove();
          boardState.reset();
          
          for (final move in game.moveHistory) {
            if (move.length >= 4) {
              final fromSquare = move.substring(0, 2);
              final toSquare = move.substring(2, 4);
              final fromCol = fromSquare.codeUnitAt(0) - 97;
              final fromRow = 8 - int.parse(fromSquare[1]);
              final toCol = toSquare.codeUnitAt(0) - 97;
              final toRow = 8 - int.parse(toSquare[1]);
              boardState.makeMove(fromRow, fromCol, toRow, toCol);
            }
          }
          hintMove = null;
          statusMessage = boardState.whiteToMove ? 'White to move' : 'Black to move';
        });
      }
    } catch (e) {
      debugPrint('Error in undo: $e');
      setState(() => statusMessage = 'Undo error: $e');
    }
  }
  
  void _newGame() {
    try {
      setState(() {
        game.reset();
        boardState.reset();
        engineOutput.clear();
        hintMove = null;
        thinking = false;
        statusMessage = 'New game - White to move';
      });
    } catch (e) {
      debugPrint('Error in new game: $e');
      setState(() => statusMessage = 'New game error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chess with Stockfish'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.blue.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(statusMessage)),
                if (thinking)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(8),
            child: ElevatedButton(
                onPressed: () {
                debugPrint('Test button clicked');
                try {
                    // Test a simple move without drag/drop
                    setState(() {
                    // Move white pawn e2-e4
                    boardState.makeMove(6, 4, 4, 4); // row 6 col 4 to row 4 col 4
                    game.makeMove('e2e4');
                    statusMessage = 'Test move made';
                    });
                    debugPrint('Test move completed');
                } catch (e) {
                    debugPrint('Test move error: $e');
                    setState(() => statusMessage = 'Test error: $e');
                }
                },
                child: Text('Test Move (e2-e4)'),
            ),
            ),
          
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ChessBoard(
                  boardState: boardState,
                  onMove: _onMove,
                  hintMove: hintMove,
                ),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _newGame,
                  icon: Icon(Icons.refresh),
                  label: Text('New Game'),
                ),
                ElevatedButton.icon(
                  onPressed: game.moveHistory.length >= 2 ? _undo : null,
                  icon: Icon(Icons.undo),
                  label: Text('Undo'),
                ),
                ElevatedButton.icon(
                  onPressed: _requestHint,
                  icon: Icon(Icons.lightbulb_outline),
                  label: Text('Hint'),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Stockfish Debug Output:',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: engineOutput.length,
                      itemBuilder: (context, index) {
                        return Text(
                          engineOutput[index],
                          style: TextStyle(
                            color: Colors.green,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}