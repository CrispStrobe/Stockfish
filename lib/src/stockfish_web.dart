import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'stockfish_state.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

final _logger = Logger('StockfishWeb');

class Stockfish {
  static Stockfish? _instance;
  
  final _state = _StockfishState();
  final _stdoutController = StreamController<String>.broadcast();
  
  web.Worker? _worker;
  String? _blobUrl;
  
  Stockfish._() {
    _initializeWorker();
  }
  
  factory Stockfish() {
    if (_instance != null) {
      throw StateError('Multiple instances are not supported, yet.');
    }
    _instance = Stockfish._();
    return _instance!;
  }
  
  ValueListenable<StockfishState> get state => _state;
  Stream<String> get stdout => _stdoutController.stream;
  
  Future<void> _initializeWorker() async {
    _logger.fine('Initializing Stockfish worker...');
    _state._setValue(StockfishState.starting);
    
    try {
      // Load Stockfish from bundled assets
      _logger.info('Loading stockfish.js from assets...');
      final stockfishCode = await rootBundle.loadString('assets/stockfish.js');
      _logger.info('Loaded ${stockfishCode.length} bytes of stockfish code');
      
      // Check if code looks valid
      if (!stockfishCode.contains('Stockfish')) {
        throw Exception('Stockfish code appears invalid - missing "Stockfish" keyword');
      }
      
      // Create a blob from the code
      _logger.info('Creating blob...');
      final blob = web.Blob(
        [stockfishCode.toJS].toJS,
        web.BlobPropertyBag(type: 'application/javascript'),
      );
      
      _blobUrl = web.URL.createObjectURL(blob);
      _logger.info('Created blob URL: $_blobUrl');
      
      // Create worker from blob URL
      _logger.info('Creating worker...');
      _worker = web.Worker(_blobUrl!.toJS);
      
      _worker!.onmessage = (web.MessageEvent event) {
        try {
          final message = (event.data as JSAny).dartify().toString();
          _logger.fine('Received: $message');
          _stdoutController.add(message);
        } catch (e) {
          _logger.warning('Error processing message: $e');
        }
      }.toJS;
      
      _worker!.onerror = (web.ErrorEvent event) {
        final errorMsg = 'Worker error: ${event.message} at ${event.filename}:${event.lineno}:${event.colno}';
        _logger.severe(errorMsg);
        _state._setValue(StockfishState.error);
      }.toJS;
      
      // Give it time to initialize
      _logger.info('Waiting for worker to initialize...');
      await Future.delayed(Duration(milliseconds: 2000));
      
      if (_state.value == StockfishState.starting) {
        _state._setValue(StockfishState.ready);
        _logger.fine('Stockfish worker ready');
      } else {
        _logger.warning('Worker did not reach ready state: ${_state.value}');
      }
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize worker: $e\n$stackTrace');
      _state._setValue(StockfishState.error);
    }
  }
  
  set stdin(String command) {
    if (_state.value != StockfishState.ready) {
      throw StateError('Stockfish is not ready (${_state.value})');
    }
    
    try {
      if (_worker != null) {
        _worker!.postMessage(command.toJS);
        _logger.finest('Sent command: $command');
      }
    } catch (e) {
      _logger.severe('Error sending command: $e');
    }
  }
  
  void dispose() {
    try {
      if (_state.value == StockfishState.ready) {
        stdin = 'quit';
      }
    } catch (e) {
      _logger.warning('Error sending quit command: $e');
    }
    
    try {
      _worker?.terminate();
      if (_blobUrl != null) {
        web.URL.revokeObjectURL(_blobUrl!);
      }
    } catch (e) {
      _logger.warning('Error terminating worker: $e');
    }
    
    _stdoutController.close();
    _state._setValue(StockfishState.disposed);
    _instance = null;
  }
}

class _StockfishState extends ChangeNotifier implements ValueListenable<StockfishState> {
  StockfishState _value = StockfishState.starting;

  @override
  StockfishState get value => _value;

  _setValue(StockfishState v) {
    if (v == _value) return;
    _value = v;
    notifyListeners();
  }
}

Future<Stockfish> stockfishAsync() {
  if (Stockfish._instance != null) {
    return Future.error(StateError('Only one instance can be used at a time'));
  }
  
  final completer = Completer<Stockfish>();
  final instance = Stockfish._();
  
  void listener() {
    if (instance.state.value == StockfishState.ready) {
      instance.state.removeListener(listener);
      completer.complete(instance);
    } else if (instance.state.value == StockfishState.error) {
      instance.state.removeListener(listener);
      completer.completeError(StateError('Failed to initialize Stockfish'));
    }
  }
  
  instance.state.addListener(listener);
  
  return completer.future;
}