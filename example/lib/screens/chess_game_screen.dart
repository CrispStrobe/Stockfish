import 'package:flutter/material.dart';
import '../chess/chess_game.dart';
import '../chess/board_state.dart';
import '../widgets/chess_board.dart';
import 'settings_screen.dart';
import 'package:stockfish/stockfish.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  late ChessGame _game;
  late BoardState _boardState;
  late Stockfish _stockfish;
  int _skillLevel = 10;
  String _statusMessage = 'Your turn (White)';
  bool _isThinking = false;
  String? _hintMove;
  String _lastMove = '';

  @override
  void initState() {
    super.initState();
    _game = ChessGame();
    _boardState = BoardState();
    _stockfish = Stockfish();
    _initializeStockfish();
  }

  void _initializeStockfish() {
    // Listen to state changes to know when the engine is actually ready
    _stockfish.state.addListener(_onStockfishStateChange);

    _stockfish.stdout.listen((line) {
        // Optimization: Clean up line and skip empty/noisy output
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) return;
        
        debugPrint('Stockfish: $trimmedLine');
        
        if (trimmedLine.startsWith('bestmove')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 2 && parts[1] != '(none)') {
            _makeStockfishMove(parts[1]);
        }
        }
    });
    }

    void _onStockfishStateChange() {
        debugPrint('Stockfish state: ${_stockfish.state.value}');
        
        // Only send configuration once the engine is ready
        if (_stockfish.state.value == StockfishState.ready) {
            _stockfish.stdin = 'uci';
            _stockfish.stdin = 'setoption name Threads value 1';
            _stockfish.stdin = 'setoption name Skill Level value $_skillLevel';
            _stockfish.stdin = 'isready';
            
            // Remove listener after initialization to avoid duplicate config calls
            _stockfish.state.removeListener(_onStockfishStateChange);
        }
    }

    void _showGameOverDialog() {
        showDialog(
            context: context,
            barrierDismissible: false, // User must click a button
            builder: (BuildContext context) {
            final winner = _game.winner;
            return AlertDialog(
                title: Text(_game.gameOverReason),
                content: Text(
                winner != null 
                    ? '$winner wins the game!' 
                    : 'The game ended in a draw.',
                ),
                actions: [
                TextButton(
                    onPressed: () {
                    Navigator.of(context).pop();
                    _newGame();
                    },
                    child: const Text('New Game'),
                ),
                ],
            );
            },
        );
    }

  void _makeStockfishMove(String uciMove) {
    if (_game.makeMove(uciMove)) {
        setState(() {
        // Replay the move on your visual board
        final fromFile = uciMove[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
        final fromRank = 8 - int.parse(uciMove[1]);
        final toFile = uciMove[2].codeUnitAt(0) - 'a'.codeUnitAt(0);
        final toRank = 8 - int.parse(uciMove[3]);

        _boardState.makeMove(fromRank, fromFile, toRank, toFile);
        
        // Handle visual promotion if move string has 5 chars (e.g. e7e8q)
        if (uciMove.length == 5) {
            _boardState.board[toRank][toFile] = ChessPiece(PieceType.queen, PieceColor.black);
        }

        _lastMove = 'Stockfish: $uciMove';
        _statusMessage = _game.isGameOver ? 'Game Over!' : 'Your turn (White)';
        _isThinking = false;
        });
    }
    }

  void _onMove(int fromRow, int fromCol, int toRow, int toCol) {
    debugPrint('UI Drag: From($fromRow, $fromCol) To($toRow, $toCol)');
    
    if (!_boardState.whiteToMove || _isThinking) {
      debugPrint('Move blocked: whiteToMove=${_boardState.whiteToMove}, isThinking=$_isThinking');
      return;
    }
    
    // 1. Prevent moving if it's not the user's turn or engine is busy
    if (!_boardState.whiteToMove || _isThinking) return;

    // 2. Convert coordinates to UCI (e.g., 'e2e4')
    final uciMove = _boardState.squareToAlgebraic(fromRow, fromCol) +
                    _boardState.squareToAlgebraic(toRow, toCol);

    // 3. Attempt the move in the logic layer
    bool isLegal = _game.makeMove(uciMove);

    if (isLegal) {
        setState(() {
        // Sync the visual board with the logic engine's FEN
        // This ensures complex moves like castling/promotion are drawn correctly
        _boardState.updateFromFen(_game.currentFEN);
        
        _lastMove = 'You: $uciMove';
        
        // Check if the game ended with this move
        if (_game.isGameOver) {
            _isThinking = false;
            _statusMessage = 'Game Over: ${_game.gameOverReason}';
            _showGameOverDialog();
        } else {
            // Move is legal and game continues: Start Stockfish
            _statusMessage = "Stockfish is thinking...";
            _isThinking = true;
            _requestStockfishMove();
        }
        });
    } else {
        // 4. Handle Illegal Move attempt
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Illegal Move!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(milliseconds: 700),
        ),
        );
    }
    }

  void _requestStockfishMove() {
    _stockfish.stdin = _game.positionCommand;
    _stockfish.stdin = 'go depth 10';
  }

  void _checkGameOver() {
    if (_game.isGameOver) {
        setState(() {
        _isThinking = false;
        _statusMessage = 'Game Over: ${_game.gameOverReason}';
        });
        _showGameOverDialog();
    }
    }

  void _getHint() {
    if (_isThinking) return;
    
    setState(() {
      _statusMessage = 'Getting hint...';
    });
    
    _stockfish.stdout.listen((line) {
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          setState(() {
            _hintMove = parts[1];
            _statusMessage = 'Hint: $_hintMove - Your turn (White)';
          });
        }
      }
    });
    
    _stockfish.stdin = _game.positionCommand;
    _stockfish.stdin = 'go depth 5';
  }

  void _undoMove() {
    if (_game.moveHistory.length < 2 || _isThinking) return;

    setState(() {
      // Remove last two moves (player and Stockfish)
      _game.undoMove();
      _game.undoMove();
      
      // Reset board and replay all moves
      _boardState.reset();
      for (var move in _game.moveHistory) {
        _replayMove(move);
      }
      _statusMessage = 'Your turn (White)';
      _hintMove = null;
    });
  }

  void _replayMove(String uciMove) {
    if (uciMove.length < 4) return;
    
    final fromFile = uciMove[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRank = 8 - int.parse(uciMove[1]);
    final toFile = uciMove[2].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRank = 8 - int.parse(uciMove[3]);

    _boardState.makeMove(fromRank, fromFile, toRank, toFile);
  }

  void _newGame() {
    setState(() {
      _game.reset();
      _boardState.reset();
      _statusMessage = 'Your turn (White)';
      _isThinking = false;
      _hintMove = null;
      _lastMove = '';
    });
  }

  Future<void> _openSettings() async {
    final newSkillLevel = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(skillLevel: _skillLevel),
      ),
    );

    if (newSkillLevel != null && newSkillLevel != _skillLevel) {
      setState(() {
        _skillLevel = newSkillLevel;
      });
      _stockfish.stdin = 'setoption name Skill Level value $_skillLevel';
    }
  }

  @override
  void dispose() {
    _stockfish.stdin = 'quit';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockfish Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isThinking ? Colors.orange.shade100 : Colors.blue.shade100,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You: White ● Stockfish: Black',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (_lastMove.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Last move: $_lastMove',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (_isThinking)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          
          // Chess board
          Expanded(
            child: Center(
              child: ChessBoard(
                boardState: _boardState,
                onMove: _onMove,
                hintMove: _hintMove,
              ),
            ),
          ),

          // Move history
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _game.moveHistory.isEmpty
                ? const Center(child: Text('No moves yet'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_game.moveHistory.length / 2).ceil(),
                    itemBuilder: (context, index) {
                      final moveNum = index + 1;
                      final whiteMove = _game.moveHistory[index * 2];
                      final blackMove = index * 2 + 1 < _game.moveHistory.length
                          ? _game.moveHistory[index * 2 + 1]
                          : null;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$moveNum. $whiteMove',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (blackMove != null)
                              Text(
                                '$moveNum... $blackMove',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _newGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Game'),
                ),
                ElevatedButton.icon(
                  onPressed: _isThinking ? null : _undoMove,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                ElevatedButton.icon(
                  onPressed: _isThinking ? null : _getHint,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}