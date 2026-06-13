# CrispChess Optimization Plan

## Overview

12 optimizations for the chess app, ordered by dependency. Each item includes file changes, before/after, and test plans.

## Current Architecture Problems

- **Triple board state**: `ChessGame._game` (chess.Chess), `MoveAnalyzer.game` (chess.Chess), `BoardState.board` (manual 2D array) -- every move syncs all three
- **Full-tree rebuilds**: 15+ state variables trigger `setState()` rebuilding header, eval bar, 64 board squares, move history, and buttons on every update
- **No engine lifecycle management**: no timeouts, no readyok verification, stream subscription leaks
- **UI-thread blocking**: tactical analysis runs synchronously on main thread
- **Dead code and deprecation warnings** throughout

---

## Phase 1: Independent (no cross-dependencies)

### 1. Eliminate Dual Board State
**Files:** `chess_game.dart`, `board_state.dart` (DELETE), `move_analyzer.dart`, `chess_game_screen.dart`, `chess_board.dart`

- Absorb `BoardState` into `ChessGame`: add `board` getter (from FEN), `whiteToMove`, `squareToAlgebraic()`
- `MoveAnalyzer` shares `ChessGame._game` reference; remove `syncMove/syncUndo/syncReset`
- Remove all `_boardState.updateFromFen()` and `_boardState.reset()` calls
- Remove `_replayMove()` method

**Tests:** `test/chess_game_test.dart` -- board getter, whiteToMove, squareToAlgebraic, undoMove, analyzer sync

### 4. Engine Lifecycle Hardening
**Files:** `engine_controller.dart`, `chess_game_screen.dart`

- Fix stream subscription leak in `detectCapabilities()` with try/finally
- Add `Future<void> waitForReady()` with Completer + timeout
- Make `requestMove()` async with 30s timeout calling `stop()`
- Handle timeout in screen: unlock board, show snackbar

**Tests:** `test/engine_controller_test.dart` -- detectCapabilities completes/times out, waitForReady, requestMove timeout

### 8. Remove Dead Code
**Files:** `chess_game_screen.dart`, `chess_game.dart`

- Remove `_applyHintMove()` (never called)
- Remove `_checkGameOver()` (never called, game-over checked inline)
- Remove `_lastBestMove` field (written, never read)

### 9. Fix Deprecation Warnings
**Files:** `chess_board.dart`

- `Color.withOpacity(x)` -> `Color.withValues(alpha: x)`
- `onWillAccept` -> `onWillAcceptWithDetails`

### 10. Plugin-Level Fixes
**Files:** `test/widget_test.dart`, `integration_test/plugin_integration_test.dart`

- Fix widget_test: check for 'CrispChess' title instead of 'Running on:'
- Fix integration_test: test Stockfish init instead of `getPlatformVersion()`

---

## Phase 2: Depends on Phase 1

### 2. Debounce Evaluation Updates
**Files:** `chess_game_screen.dart`

- Buffer `cp`, `depth`, `bestMove` from info lines
- Start/restart 200ms debounce timer on each info line
- Call `updateEvaluation()` + update notifiers only when timer fires
- Reduces annotation + notifier updates from 50-100/sec to 5/sec

**Tests:** `test/eval_debounce_test.dart` -- rapid lines don't trigger update, debounce settles, latest values win

### 3. Consolidate State Variables
**Files:** NEW `chess/game_state.dart`, `chess_game_screen.dart`

- Immutable `GameState` class with `copyWith()`
- Replace 15+ fields with single `_state` field
- `setState(() => _state = _state.copyWith(isThinking: true, ...))`

**Tests:** `test/game_state_test.dart` -- copyWith preserves/updates fields, defaults correct

### 5. Cache Legal Moves
**Files:** `chess_game.dart`, `chess_game_screen.dart`

- `_cachedLegalMoves` field, lazily populated in `getLegalMoves()`
- Invalidated on `makeMove()`, `undoMove()`, `reset()`
- `_getValidMovesForSquare()` filters cached list

**Tests:** `test/chess_game_test.dart` -- cache stability, invalidation on move/undo/reset

### 6. ChessBoard Widget Optimization
**Files:** `chess_board.dart`

- Wrap board in `RepaintBoundary`
- Extract `_ChessSquare` as separate widget with pre-computed bool props
- Convert `validMoves` to `Set<String>` for O(1) target lookup
- Pre-compute per-square state in parent build

**Tests:** `test/chess_board_widget_test.dart` -- 64 squares rendered, selection/hint/valid-target highlights

---

## Phase 3: Depends on Phase 2

### 7. Move Analyzer to Isolate
**Files:** `move_analyzer.dart`, `chess_game.dart`

- Top-level `analyzeInIsolate(AnalysisRequest)` function
- `AnalysisRequest` holds FEN + UCI move + evaluation (serializable)
- Use `compute()` to run off main thread
- `ChessGame.makeMove()` stores `Future<MoveAnnotation>`

**Tests:** `test/move_analyzer_test.dart` -- fork detection, material gain, game phase, promotions

### 11. State Management with ChangeNotifier
**Files:** `chess_game.dart`, `chess_game_screen.dart`, `chess_board.dart`

- `ChessGame extends ChangeNotifier`
- `notifyListeners()` after makeMove/undoMove/reset
- Screen uses `ListenableBuilder` for board, move history, controls
- Eliminates full-tree rebuilds

**Tests:** `test/chess_game_test.dart` -- notifyListeners called on state changes; `test/chess_game_screen_test.dart` -- selective rebuilds

---

## Phase 4: Depends on Phase 3

### 12. Separate Engine Service Layer
**Files:** NEW `services/engine_service.dart`, `chess_game_screen.dart`

- `EngineService` owns Stockfish + EngineController
- Exposes `Stream<EngineEvent>` (sealed class: EvalUpdate, BestMove, StateChange, EngineError)
- Handles stdout parsing, debouncing, readyok handshake internally
- Screen becomes thin consumer with `switch` on events

**Tests:** `test/engine_service_test.dart` -- event emission, debounce, reinitialize, dispose; `integration_test/engine_service_test.dart` -- full lifecycle

---

## New Files Summary

| File | Opt# | Purpose |
|------|------|---------|
| `lib/chess/game_state.dart` | 3 | Immutable state class |
| `lib/services/engine_service.dart` | 12 | Engine abstraction |
| `test/chess_game_test.dart` | 1,5,11 | ChessGame unit tests |
| `test/game_state_test.dart` | 3 | GameState unit tests |
| `test/engine_controller_test.dart` | 4 | EngineController tests |
| `test/eval_debounce_test.dart` | 2 | Debounce tests |
| `test/move_analyzer_test.dart` | 7 | Isolate analyzer tests |
| `test/chess_board_widget_test.dart` | 6 | Board widget tests |
| `test/chess_game_screen_test.dart` | 11 | Screen widget tests |
| `test/engine_service_test.dart` | 12 | EngineService tests |

## Deleted Files

| File | Opt# | Reason |
|------|------|--------|
| `lib/chess/board_state.dart` | 1 | Merged into ChessGame |

---

## Progress Tracking

- [x] 1. Eliminate dual board state
- [x] 4. Engine lifecycle hardening
- [x] 8. Remove dead code
- [x] 9. Fix deprecation warnings
- [x] 10. Plugin-level fixes
- [x] 2. Debounce evaluation updates
- [x] 3. Consolidate state variables
- [x] 5. Cache legal moves
- [x] 6. ChessBoard widget optimization
- [x] 7. Move analyzer to isolate
- [x] 11. State management (ChangeNotifier)
- [x] 12. Separate engine service layer
