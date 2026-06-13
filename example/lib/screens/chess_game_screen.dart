import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/chess_game.dart';
import '../widgets/chess_board.dart';
import 'settings_screen.dart';
import 'package:stockfish/stockfish.dart';
import '../widgets/horizontal_evaluation_bar.dart';
import '../chess/engine_controller.dart';
import '../chess/engine_capabilities.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  late ChessGame _game;
  late Stockfish _stockfish;
  late EngineController _engineController;

  // Pre-compiled regex patterns for parsing engine output
  static final _cpRegex = RegExp(r'score cp (-?\d+)');
  static final _depthRegex = RegExp(r'depth (\d+)');
  static final _pvRegex = RegExp(r'pv (\S+)');

  int _strengthLevel = 10;  // 0-20 scale
  int _hintDepth = 15;

  bool _showValidMoves = true;
  bool _animateMoves = true;
  int? _selectedRow;
  int? _selectedCol;
  List<String> _validMoves = [];  // UCI format moves

  String _statusMessage = 'Your turn (White)';
  bool _isThinking = false;
  String? _hintMove;
  String _lastMove = '';
  bool _waitingForHint = false;

  // Evaluation state managed via ValueNotifier to avoid full rebuilds
  final ValueNotifier<double?> _evalNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<int> _depthNotifier = ValueNotifier<int>(0);
  String? _currentBestMove;

  // Debounce timer for evaluation updates
  Timer? _evalDebounce;

  @override
  void initState() {
    super.initState();
    _game = ChessGame();
    _stockfish = Stockfish();
    _engineController = EngineController(_stockfish);
    _initializeStockfish();
  }

  List<String> _getValidMovesForSquare(int row, int col) {
    final square = _game.squareToAlgebraic(row, col);
    final piece = _game.board[row][col];

    if (piece == null || piece.color != PieceColor.white) return [];

    // Get all legal moves from the game
    final allMoves = _game.getLegalMoves();

    // Filter to moves starting from this square
    return allMoves.where((move) => move.startsWith(square)).toList();
    }

  void _initializeStockfish() {
    _stockfish.state.addListener(_onStockfishStateChange);

    _stockfish.stdout.listen((line) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) return;

      debugPrint('Stockfish: $trimmedLine');

      // Parse evaluation info using pre-compiled regex
      if (trimmedLine.startsWith('info') && trimmedLine.contains('depth')) {
        final cpMatch = _cpRegex.firstMatch(trimmedLine);
        final depthMatch = _depthRegex.firstMatch(trimmedLine);
        final pvMatch = _pvRegex.firstMatch(trimmedLine);

        if (cpMatch != null && depthMatch != null) {
          final cp = int.parse(cpMatch.group(1)!);
          final depth = int.parse(depthMatch.group(1)!);
          final bestMove = pvMatch?.group(1) ?? '';

          // Update ValueNotifiers (no setState needed for eval bar)
          _evalNotifier.value = cp / 100.0;
          _depthNotifier.value = depth;
          if (bestMove.isNotEmpty) _currentBestMove = bestMove;

          if (bestMove.isNotEmpty) {
            _game.updateEvaluation(_evalNotifier.value!, bestMove, depth);
          }
        }
      }

      if (trimmedLine.startsWith('bestmove')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 2 && parts[1] != '(none)') {
          final move = parts[1];

          if (_waitingForHint) {
            _handleHintResponse(move);
          } else if (_isThinking) {
            _makeStockfishMove(move);
          }
        }
      }
    });
  }


    void _onStockfishStateChange() async {
    final currentState = _stockfish.state.value;

    if (currentState == StockfishState.ready) {
      try {
        await _engineController.detectCapabilities();

        final settings = StrengthSettings.fromLevel(_strengthLevel);
        _engineController.applyStrength(settings);

        _stockfish.stdin = 'isready';

        if (mounted) {
          setState(() {
            _statusMessage = 'Your turn (White)';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Engine error - please restart';
          });
        }
      }

      _stockfish.state.removeListener(_onStockfishStateChange);
    } else if (currentState == StockfishState.error) {
      debugPrint('Stockfish failed to initialize!');

      setState(() {
        _statusMessage = 'Chess engine failed to start';
        _isThinking = false;
      });

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
  debugPrint('Attempting to reinitialize Stockfish...');

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
    debugPrint('Failed to reinitialize: $e');
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

        // DO NOT request any further analysis after a hint - that was causing auto-execution
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
        _lastMove = 'Stockfish: $uciMove';
        _statusMessage = _game.isGameOver ? 'Game Over!' : 'Your turn (White)';
        _isThinking = false;
        });

        // DO NOT automatically request analysis here
        // Analysis will happen naturally when the player makes their next move
    }
    }

  void _onSquareTap(int row, int col) {
    if (!_game.whiteToMove || _isThinking) return;

    final piece = _game.board[row][col];

    // If we have a piece selected
    if (_selectedRow != null && _selectedCol != null) {
        // Try to move to this square
        _onMove(_selectedRow!, _selectedCol!, row, col);

        // Clear selection
        setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _validMoves = [];
        });
    } else if (piece != null && piece.color == PieceColor.white) {
        // Select this piece
        setState(() {
        _selectedRow = row;
        _selectedCol = col;
        if (_showValidMoves) {
            _validMoves = _getValidMovesForSquare(row, col);
        }
        });
    }
    }

  void _onMove(int fromRow, int fromCol, int toRow, int toCol) {
    debugPrint('UI Move: From($fromRow, $fromCol) To($toRow, $toCol)');

    if (!_game.whiteToMove || _isThinking) {
        debugPrint('Move blocked: whiteToMove=${_game.whiteToMove}, isThinking=$_isThinking');
        return;
    }

    if (_stockfish.state.value != StockfishState.ready) {
        debugPrint('Stockfish is not ready: ${_stockfish.state.value}');
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Chess engine is not ready. Please wait or restart the app.'),
            backgroundColor: Colors.orange,
        ),
        );
        return;
    }

    final uciMove = _game.squareToAlgebraic(fromRow, fromCol) +
                    _game.squareToAlgebraic(toRow, toCol);

    bool isLegal = _game.makeMove(uciMove);

    if (isLegal) {
        setState(() {
        _lastMove = 'You: $uciMove';
        _hintMove = null;

        if (_game.isGameOver) {
            _isThinking = false;
            _statusMessage = 'Game Over: ${_game.gameOverReason}';
            _showGameOverDialog();
        } else {
            _statusMessage = "Stockfish is thinking...";
            _isThinking = true;

            // Request Stockfish to make its move
            _requestStockfishMove();
        }
        });
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Illegal Move!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(milliseconds: 700),
        ),
        );
    }
    }

  Future<void> _requestStockfishMove() async {
    if (_stockfish.state.value != StockfishState.ready) {
      debugPrint('Cannot request move - Stockfish not ready');
      setState(() {
        _isThinking = false;
        _statusMessage = 'Engine error - your turn';
      });
      return;
    }

    final settings = StrengthSettings.fromLevel(_strengthLevel);
    _engineController.applyStrength(settings);
    await _engineController.requestMove(_game.positionCommand, settings);
  }

  Future<void> _getHint() async {
    if (_stockfish.state.value != StockfishState.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engine not ready')),
      );
      return;
    }

    if (!_game.whiteToMove || _isThinking) return;

    setState(() {
      _waitingForHint = true;
      _isThinking = true;
      _statusMessage = 'Analyzing position...';
    });

    // Use full strength for hints
    await _engineController.requestAnalysis(_game.positionCommand, _hintDepth);
  }

  void _undoMove() {
    if (_game.moveHistory.length < 2) return;
    // Stop engine if it's currently thinking
    if (_isThinking) {
      _engineController.stop();
      _isThinking = false;
    }

    setState(() {
      // Remove last two moves (player and Stockfish)
      _game.undoMove();
      _game.undoMove();

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

  void _newGame() {
    _evalNotifier.value = null;
    _depthNotifier.value = 0;
    _currentBestMove = null;
    setState(() {
      _game.reset();
      _statusMessage = 'Your turn (White)';
      _isThinking = false;
      _hintMove = null;
      _lastMove = '';
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
        builder: (context) => SettingsScreen(
            strengthLevel: _strengthLevel,
            hintDepth: _hintDepth,
        ),
        ),
    );

    if (result != null) {
        setState(() {
        _strengthLevel = result['strengthLevel']! as int;
        _hintDepth = result['hintDepth']! as int;
        _showValidMoves = result['showValidMoves']! as bool;
        _animateMoves = result['animateMoves']! as bool;
        });

        // Apply new strength settings
        final settings = StrengthSettings.fromLevel(_strengthLevel);
        _engineController.applyStrength(settings);
    }
    }

  @override
void dispose() {
  _evalDebounce?.cancel();
  _evalNotifier.dispose();
  _depthNotifier.dispose();
  _stockfish.state.removeListener(_onStockfishStateChange);
  _stockfish.dispose();
  super.dispose();
}

@override
void reassemble() {
  debugPrint('Hot reload detected - reassembling');
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
                child:
                  ChessBoard(
                    board: _game.board,
                    whiteToMove: _game.whiteToMove,
                    squareToAlgebraic: _game.squareToAlgebraic,
                    onMove: _onMove,
                    onSquareTap: _onSquareTap,
                    selectedRow: _selectedRow,
                    selectedCol: _selectedCol,
                    validMoves: _validMoves,
                    hintMove: _hintMove,
                    isCheck: _game.inCheck,
                    animateMoves: _animateMoves,
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
  final hasAnnotations = _game.annotations.isNotEmpty;

  if (_evalNotifier.value == null && !hasAnnotations) return const SizedBox.shrink();

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
                if (!_analysisExpanded)
                  ValueListenableBuilder<double?>(
                    valueListenable: _evalNotifier,
                    builder: (context, eval, _) {
                      if (eval == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: eval >= 0 ? Colors.blue.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          eval >= 0
                              ? '+${eval.toStringAsFixed(1)}'
                              : eval.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: eval >= 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      );
                    },
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
          // Horizontal evaluation bar (isolated rebuild via ValueListenableBuilder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ValueListenableBuilder<double?>(
              valueListenable: _evalNotifier,
              builder: (context, eval, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _depthNotifier,
                  builder: (context, depth, _) {
                    return HorizontalEvaluationBar(
                      evaluation: eval,
                      depth: depth,
                    );
                  },
                );
              },
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
          onPressed: (!_game.whiteToMove || _isThinking) ? null : _getHint,
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
