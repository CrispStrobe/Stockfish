import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'stockfish_method_channel.dart';

abstract class StockfishPlatform extends PlatformInterface {
  /// Constructs a StockfishPlatform.
  StockfishPlatform() : super(token: _token);

  static final Object _token = Object();

  static StockfishPlatform _instance = MethodChannelStockfish();

  /// The default instance of [StockfishPlatform] to use.
  ///
  /// Defaults to [MethodChannelStockfish].
  static StockfishPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [StockfishPlatform] when
  /// they register themselves.
  static set instance(StockfishPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
