import 'package:flutter/material.dart';
import '../chess/chess_game.dart';
import '../chess/board_state.dart';
import '../widgets/chess_board.dart';
import 'settings_screen.dart';
import 'package:stockfish/stockfish.dart';
import '../widgets/horizontal_evaluation_bar.dart';

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
  bool _waitingForHint = false;

  double? _currentEvaluation; // in centipawns
  int _searchDepth = 0;
  String? _bestLine;
  String? _currentBestMove;
  int _analysisDepth = 0;

  @override
  void initState() {
    super.initState();
    _game = ChessGame();
    _boardState = BoardState();
    _stockfish = Stockfish();
    _initializeStockfish();
  }

  void _initializeStockfish() {
  // Listen to state changes
  _stockfish.state.addListener(_onStockfishStateChange);

  _stockfish.stdout.listen((line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty) return;
    
    debugPrint('📊 Stockfish: $trimmedLine');
    
    // Parse evaluation and best move
    if (trimmedLine.startsWith('info') && trimmedLine.contains('depth')) {
      final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(trimmedLine);
      final depthMatch = RegExp(r'depth (\d+)').firstMatch(trimmedLine);
      final pvMatch = RegExp(r'pv (\S+)').firstMatch(trimmedLine);
      
      if (cpMatch != null && depthMatch != null) {
        final cp = int.parse(cpMatch.group(1)!);
        final depth = int.parse(depthMatch.group(1)!);
        final bestMove = pvMatch?.group(1);
        
        setState(() {
          _currentEvaluation = cp / 100.0;
          _analysisDepth = depth;
          if (bestMove != null) _currentBestMove = bestMove;
        });
        
        // Update game evaluation
        if (bestMove != null) {
          _game.updateEvaluation(_currentEvaluation!, bestMove, depth);
        }
      }
    }
    
    if (trimmedLine.startsWith('bestmove')) {
      final parts = trimmedLine.split(' ');
      if (parts.length >= 2 && parts[1] != '(none)') {
        final move = parts[1];
        
        // Distinguish between a requested hint and a normal AI turn
        if (_waitingForHint) {
          _handleHintResponse(move);
        } else {
          _makeStockfishMove(move);
        }
      }
    }
  });
}

void _onStockfishStateChange() {
  final currentState = _stockfish.state.value;
  debugPrint('🔄 Stockfish state changed to: $currentState');
  
  if (currentState == StockfishState.ready) {
    debugPrint('✅ Stockfish is ready, initializing...');
    
    try {
      _stockfish.stdin = 'uci';
      _stockfish.stdin = 'setoption name Threads value 1';
      _stockfish.stdin = 'setoption name Skill Level value $_skillLevel';
      _stockfish.stdin = 'isready';
      
      setState(() {
        _statusMessage = 'Your turn (White)';
      });
    } catch (e) {
      debugPrint('❌ Error configuring Stockfish: $e');
      setState(() {
        _statusMessage = 'Engine error - please restart';
      });
    }
    
    // Remove listener after initialization
    _stockfish.state.removeListener(_onStockfishStateChange);
  } else if (currentState == StockfishState.error) {
    debugPrint('❌ Stockfish failed to initialize!');
    
    // Show error to user
    setState(() {
      _statusMessage = 'Chess engine failed to start';
      _isThinking = false;
    });
    
    // Show dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Engine Error'),
          content: Text(
            'The chess engine failed to initialize. Please restart the app.\n\n'
            'If the problem persists, try reinstalling the app.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try to reinitialize
                _tryReinitializeStockfish();
              },
              child: Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
    });
  }
}

void _tryReinitializeStockfish() {
  debugPrint('🔄 Attempting to reinitialize Stockfish...');
  
  try {
    // Dispose old instance
    _stockfish.dispose();
    
    // Create new instance
    setState(() {
      _stockfish = Stockfish();
      _initializeStockfish();
      _statusMessage = 'Restarting engine...';
    });
  } catch (e) {
    debugPrint('❌ Failed to reinitialize: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to restart engine: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

   
    void _handleHintResponse(String uciMove) {
    if (!mounted) return;

    setState(() {
        _waitingForHint = false; // Stop waiting
        _isThinking = false;     // UNLOCK the board so user can move
        _hintMove = uciMove;     // This triggers the yellow highlight in ChessBoard
        _statusMessage = 'Hint: $uciMove';
    });
    }

  void _applyHintMove(String uciMove) {
    // 1. Validate and Logic Move
    if (_game.makeMove(uciMove)) {
      setState(() {
        // 2. Update Visual Board
        _boardState.updateFromFen(_game.currentFEN);
        _lastMove = 'You (Hint): $uciMove';
        _hintMove = null; // Clear highlight

        // 3. Check Game Over or Continue
        if (_game.isGameOver) {
          _statusMessage = 'Game Over: ${_game.gameOverReason}';
          _showGameOverDialog();
        } else {
          // 4. Hand over to Stockfish (Black)
          _statusMessage = "Stockfish is thinking...";
          _isThinking = true;
          _requestStockfishMove();
        }
      });
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
    
    // CHECK STOCKFISH STATE BEFORE PROCEEDING
    if (_stockfish.state.value != StockfishState.ready) {
        debugPrint('⚠️ Stockfish is not ready: ${_stockfish.state.value}');
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Chess engine is not ready. Please wait or restart the app.'),
            backgroundColor: Colors.orange,
        ),
        );
        return;
    }
    
    // Convert coordinates to UCI (e.g., 'e2e4')
    final uciMove = _boardState.squareToAlgebraic(fromRow, fromCol) +
                    _boardState.squareToAlgebraic(toRow, toCol);

    // Attempt the move in the logic layer
    bool isLegal = _game.makeMove(uciMove);

    if (isLegal) {
        setState(() {
        // Sync the visual board with the logic engine's FEN
        _boardState.updateFromFen(_game.currentFEN);
        
        _lastMove = 'You: $uciMove';
        _hintMove = null;
        
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
        // Handle Illegal Move attempt
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
  // CHECK STATE FIRST
  if (_stockfish.state.value != StockfishState.ready) {
    debugPrint('❌ Cannot request move - Stockfish not ready');
    setState(() {
      _isThinking = false;
      _statusMessage = 'Engine error - your turn';
    });
    return;
  }
  
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
  // CHECK STATE FIRST
  if (_stockfish.state.value != StockfishState.ready) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Engine not ready')),
    );
    return;
  }
  
  if (!_boardState.whiteToMove || _isThinking) return;

  setState(() {
    _waitingForHint = true;
    _isThinking = true;
    _statusMessage = 'Analyzing position...';
  });

  _stockfish.stdin = _game.positionCommand;
  _stockfish.stdin = 'go depth 10';
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

  Color _getStockfishStatusColor() {
  switch (_stockfish.state.value) {
    case StockfishState.ready:
      return Colors.green;
    case StockfishState.starting:
      return Colors.orange;
    case StockfishState.error:
      return Colors.red;
    case StockfishState.disposed:
      return Colors.grey;
  }
}

IconData _getStockfishStatusIcon() {
  switch (_stockfish.state.value) {
    case StockfishState.ready:
      return Icons.check_circle;
    case StockfishState.starting:
      return Icons.hourglass_empty;
    case StockfishState.error:
      return Icons.error;
    case StockfishState.disposed:
      return Icons.power_off;
  }
}

String _getStockfishStatusText() {
  switch (_stockfish.state.value) {
    case StockfishState.ready:
      return 'Ready';
    case StockfishState.starting:
      return 'Starting...';
    case StockfishState.error:
      return 'Error';
    case StockfishState.disposed:
      return 'Stopped';
  }
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
  debugPrint('🔴 Disposing ChessGameScreen');
  _stockfish.state.removeListener(_onStockfishStateChange);
  _stockfish.dispose();
  super.dispose();
}

@override
void reassemble() {
  debugPrint('♻️ Hot reload detected - reassembling');
  super.reassemble();
  // Don't reinitialize Stockfish on hot reload, just continue
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('CrispChess'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettings,
        ),
      ],
    ),
    body: Column(
      children: [
        // Compact status header
        _buildCompactHeader(),
        
        // Collapsible analysis panel
        _buildAnalysisPanel(),
        
        // Chess board
        Expanded(
        child: Center(
            child: LayoutBuilder(
            builder: (context, constraints) {
                // Calculate the size for a square board
                final size = constraints.maxHeight < constraints.maxWidth
                    ? constraints.maxHeight
                    : constraints.maxWidth;
                
                return SizedBox(
                width: size,
                height: size,
                child: ChessBoard(
                    boardState: _boardState,
                    onMove: _onMove,
                    hintMove: _hintMove,
                    isCheck: _game.inCheck,
                ),
                );
            },
            ),
        ),
        ),

        // Compact move history
        _buildMoveHistory(),

        // Control buttons
        _buildControlButtons(),
      ],
    ),
  );
}

// Compact header with everything in one row
Widget _buildCompactHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _isThinking ? Colors.orange.shade100 : Colors.blue.shade100,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Row(
      children: [
        // Status icon
        Icon(
          _isThinking ? Icons.hourglass_empty : Icons.check_circle,
          size: 20,
          color: _isThinking ? Colors.orange : Colors.green,
        ),
        const SizedBox(width: 8),
        
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_lastMove.isNotEmpty)
                Text(
                  _lastMove,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
            ],
          ),
        ),
        
        // Engine status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStockfishStatusColor(),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStockfishStatusIcon(),
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                _getStockfishStatusText(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
        
        // Loading spinner
        if (_isThinking)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    ),
  );
}

// Collapsible analysis panel with two columns and eval bar
bool _analysisExpanded = false;

Widget _buildAnalysisPanel() {
  // Always show if we have evaluation data
  final hasEvaluation = _currentEvaluation != null;
  final hasAnnotations = _game.annotations.isNotEmpty;
  
  if (!hasEvaluation && !hasAnnotations) return const SizedBox.shrink();
  
  // Get last two annotations (player and Stockfish)
  final annotations = _game.annotations;
  final playerAnnotation = annotations.length >= 2 ? annotations[annotations.length - 2] : null;
  final stockfishAnnotation = annotations.isNotEmpty ? annotations.last : null;
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Column(
      children: [
        // Header with expand/collapse button
        InkWell(
          onTap: () => setState(() => _analysisExpanded = !_analysisExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Move Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                
                // Show current evaluation in header when collapsed
                if (!_analysisExpanded && hasEvaluation)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _currentEvaluation! >= 0 ? Colors.blue.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _currentEvaluation! >= 0 
                          ? '+${_currentEvaluation!.toStringAsFixed(1)}'
                          : _currentEvaluation!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _currentEvaluation! >= 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                  
                const SizedBox(width: 8),
                Icon(
                  _analysisExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        
        // Expandable content
        if (_analysisExpanded) ...[
          // Horizontal evaluation bar
          if (hasEvaluation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: HorizontalEvaluationBar(
                evaluation: _currentEvaluation,
                depth: _analysisDepth,
              ),
            ),
          
          // Two-column move analysis
          if (hasAnnotations)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player move (left column)
                  if (playerAnnotation != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'You: ${playerAnnotation.move}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              playerAnnotation.getFullDescription(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // Stockfish move (right column)
                  if (stockfishAnnotation != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.computer, size: 14, color: Colors.grey.shade700),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Stockfish: ${stockfishAnnotation.move}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stockfishAnnotation.getFullDescription(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

// Compact move history
Widget _buildMoveHistory() {
  return Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border(top: BorderSide(color: Colors.grey.shade300)),
    ),
    child: _game.moveHistory.isEmpty
        ? const Center(
            child: Text(
              'No moves yet',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
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
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Text(
                      '$moveNum.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      whiteMove,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (blackMove != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        blackMove,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
  );
}

// Compact control buttons
Widget _buildControlButtons() {
  return Container(
    padding: const EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCompactButton(
          icon: Icons.refresh,
          label: 'New',
          onPressed: _newGame,
        ),
        _buildCompactButton(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: _isThinking ? null : _undoMove,
        ),
        _buildCompactButton(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          onPressed: (!_boardState.whiteToMove || _isThinking) ? null : _getHint,
        ),
      ],
    ),
  );
}

Widget _buildCompactButton({
  required IconData icon,
  required String label,
  required VoidCallback? onPressed,
}) {
  return Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}


}