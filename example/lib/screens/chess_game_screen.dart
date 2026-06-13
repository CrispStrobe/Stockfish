import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/chess_game.dart';
import '../chess/game_state.dart';
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

  // Consolidated state
  GameState _state = const GameState();

  // Evaluation state managed via ValueNotifier to avoid full rebuilds
  final ValueNotifier<double?> _evalNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<int> _depthNotifier = ValueNotifier<int>(0);

  // Debounce timer and buffered values for evaluation updates
  Timer? _evalDebounce;
  double? _bufferedEval;
  int _bufferedDepth = 0;
  String? _bufferedBestMove;

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

          // Buffer values and debounce updates
          _bufferedEval = cp / 100.0;
          _bufferedDepth = depth;
          if (bestMove.isNotEmpty) _bufferedBestMove = bestMove;

          _evalDebounce?.cancel();
          _evalDebounce = Timer(const Duration(milliseconds: 200), () {
            _evalNotifier.value = _bufferedEval;
            _depthNotifier.value = _bufferedDepth;
            if (_bufferedBestMove != null) {
              setState(() {
                _state = _state.copyWith(currentBestMove: _bufferedBestMove);
              });
            }
            if (_bufferedBestMove != null && _bufferedEval != null) {
              _game.updateEvaluation(
                  _bufferedEval!, _bufferedBestMove!, _bufferedDepth);
            }
          });
        }
      }

      if (trimmedLine.startsWith('bestmove')) {
        final parts = trimmedLine.split(' ');
        if (parts.length >= 2 && parts[1] != '(none)') {
          final move = parts[1];

          if (_state.waitingForHint) {
            _handleHintResponse(move);
          } else if (_state.isThinking) {
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

        final settings = StrengthSettings.fromLevel(_state.strengthLevel);
        _engineController.applyStrength(settings);

        _stockfish.stdin = 'isready';

        if (mounted) {
          setState(() {
            _state = _state.copyWith(statusMessage: 'Your turn (White)');
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _state =
                _state.copyWith(statusMessage: 'Engine error - please restart');
          });
        }
      }

      _stockfish.state.removeListener(_onStockfishStateChange);
    } else if (currentState == StockfishState.error) {
      debugPrint('Stockfish failed to initialize!');

      setState(() {
        _state = _state.copyWith(
          statusMessage: 'Chess engine failed to start',
          isThinking: false,
        );
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Engine Error'),
            content: Text(
                'The chess engine failed to initialize. Please restart the app.\n\n'
                'If the problem persists, try reinstalling the app.'),
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
        _state = _state.copyWith(statusMessage: 'Restarting engine...');
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
      _state = _state.copyWith(
        waitingForHint: false,
        isThinking: false,
        hintMove: uciMove,
        statusMessage: 'Hint: $uciMove',
      );
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                _state = _state.copyWith(
          lastMove: 'Stockfish: $uciMove',
          statusMessage:
              _game.isGameOver ? 'Game Over!' : 'Your turn (White)',
          isThinking: false,
        );
      });
    }
  }

  void _onSquareTap(int row, int col) {
    if (!_game.whiteToMove || _state.isThinking) return;

    final piece = _game.board[row][col];

    // If we have a piece selected
    if (_state.selectedRow != null && _state.selectedCol != null) {
      // Try to move to this square
      _onMove(_state.selectedRow!, _state.selectedCol!, row, col);

      // Clear selection
      setState(() {
        _state = _state.copyWith(
          selectedRow: null,
          selectedCol: null,
          validMoves: const [],
        );
      });
    } else if (piece != null && piece.color == PieceColor.white) {
      // Select this piece
      setState(() {
        _state = _state.copyWith(
          selectedRow: row,
          selectedCol: col,
          validMoves: _state.showValidMoves
              ? _getValidMovesForSquare(row, col)
              : const [],
        );
      });
    }
  }

  void _onMove(int fromRow, int fromCol, int toRow, int toCol) {
    debugPrint('UI Move: From($fromRow, $fromCol) To($toRow, $toCol)');

    if (!_game.whiteToMove || _state.isThinking) {
      debugPrint(
          'Move blocked: whiteToMove=${_game.whiteToMove}, isThinking=${_state.isThinking}');
      return;
    }

    if (_stockfish.state.value != StockfishState.ready) {
      debugPrint('Stockfish is not ready: ${_stockfish.state.value}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Chess engine is not ready. Please wait or restart the app.'),
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
                _state = _state.copyWith(
          lastMove: 'You: $uciMove',
          hintMove: null,
        );

        if (_game.isGameOver) {
          _state = _state.copyWith(
            isThinking: false,
            statusMessage: 'Game Over: ${_game.gameOverReason}',
          );
          _showGameOverDialog();
        } else {
          _state = _state.copyWith(
            statusMessage: 'Stockfish is thinking...',
            isThinking: true,
          );

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

  void _requestStockfishMove() {
    if (_stockfish.state.value != StockfishState.ready) {
      debugPrint('Cannot request move - Stockfish not ready');
      setState(() {
        _state = _state.copyWith(
          isThinking: false,
          statusMessage: 'Engine error - your turn',
        );
      });
      return;
    }

    final settings = StrengthSettings.fromLevel(_state.strengthLevel);
    _engineController.applyStrength(settings);
    _engineController.requestMove(_game.positionCommand, settings);
  }

  void _getHint() {
    if (_stockfish.state.value != StockfishState.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engine not ready')),
      );
      return;
    }

    if (!_game.whiteToMove || _state.isThinking) return;

    setState(() {
      _state = _state.copyWith(
        waitingForHint: true,
        isThinking: true,
        statusMessage: 'Analyzing position...',
      );
    });

    // Use full strength for hints
    _engineController.requestAnalysis(
        _game.positionCommand, _state.hintDepth);
  }

  void _undoMove() {
    if (_game.moveHistory.length < 2) return;
    // Stop engine if it's currently thinking
    if (_state.isThinking) {
      _engineController.stop();
    }

    setState(() {
      _game.undoMove();
      _game.undoMove();
      _state = _state.copyWith(
        statusMessage: 'Your turn (White)',
        hintMove: null,
        isThinking: false,
      );
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
    setState(() {
      _game.reset();
            _state = _state.copyWith(
        statusMessage: 'Your turn (White)',
        isThinking: false,
        hintMove: null,
        lastMove: '',
        currentBestMove: null,
      );
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          strengthLevel: _state.strengthLevel,
          hintDepth: _state.hintDepth,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _state = _state.copyWith(
          strengthLevel: result['strengthLevel']! as int,
          hintDepth: result['hintDepth']! as int,
          showValidMoves: result['showValidMoves']! as bool,
          animateMoves: result['animateMoves']! as bool,
        );
      });

      // Apply new strength settings
      final settings = StrengthSettings.fromLevel(_state.strengthLevel);
      _engineController.applyStrength(settings);
    }
  }

  @override
  void dispose() {
    _evalDebounce?.cancel();
    _evalNotifier.dispose();
    _depthNotifier.dispose();
    _game.dispose();
    _stockfish.state.removeListener(_onStockfishStateChange);
    _stockfish.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    debugPrint('Hot reload detected - reassembling');
    super.reassemble();
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

          // Chess board (rebuilds only when ChessGame notifies)
          Expanded(
            child: ListenableBuilder(
              listenable: _game,
              builder: (context, _) {
                return Center(
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
                          board: _game.board,
                          whiteToMove: _game.whiteToMove,
                          squareToAlgebraic: _game.squareToAlgebraic,
                          onMove: _onMove,
                          onSquareTap: _onSquareTap,
                          selectedRow: _state.selectedRow,
                          selectedCol: _state.selectedCol,
                          validMoves: _state.validMoves,
                          hintMove: _state.hintMove,
                          isCheck: _game.inCheck,
                          animateMoves: _state.animateMoves,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Compact move history (rebuilds only when ChessGame notifies)
          ListenableBuilder(
            listenable: _game,
            builder: (context, _) {
              return _buildMoveHistory();
            },
          ),

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
        color: _state.isThinking
            ? Colors.orange.shade100
            : Colors.blue.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Status icon
          Icon(
            _state.isThinking ? Icons.hourglass_empty : Icons.check_circle,
            size: 20,
            color: _state.isThinking ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _state.statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_state.lastMove.isNotEmpty)
                  Text(
                    _state.lastMove,
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
                  style:
                      const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),

          // Loading spinner
          if (_state.isThinking)
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

  Widget _buildAnalysisPanel() {
    // Always show if we have evaluation data
    final hasAnnotations = _game.annotations.isNotEmpty;

    if (_evalNotifier.value == null && !hasAnnotations) {
      return const SizedBox.shrink();
    }

    // Get last two annotations (player and Stockfish)
    final annotations = _game.annotations;
    final playerAnnotation = annotations.length >= 2
        ? annotations[annotations.length - 2]
        : null;
    final stockfishAnnotation =
        annotations.isNotEmpty ? annotations.last : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () => setState(() {
              _state = _state.copyWith(
                  analysisExpanded: !_state.analysisExpanded);
            }),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  if (!_state.analysisExpanded)
                    ValueListenableBuilder<double?>(
                      valueListenable: _evalNotifier,
                      builder: (context, eval, _) {
                        if (eval == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: eval >= 0
                                ? Colors.blue.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            eval >= 0
                                ? '+${eval.toStringAsFixed(1)}'
                                : eval.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: eval >= 0
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(width: 8),
                  Icon(
                    _state.analysisExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_state.analysisExpanded) ...[
            // Horizontal evaluation bar (isolated rebuild via ValueListenableBuilder)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            border:
                                Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person,
                                      size: 14,
                                      color: Colors.blue.shade700),
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
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.computer,
                                      size: 14,
                                      color: Colors.grey.shade700),
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
                final blackMove =
                    index * 2 + 1 < _game.moveHistory.length
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
            onPressed: _state.isThinking ? null : _undoMove,
          ),
          _buildCompactButton(
            icon: Icons.lightbulb_outline,
            label: 'Hint',
            onPressed: (!_game.whiteToMove || _state.isThinking)
                ? null
                : _getHint,
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
