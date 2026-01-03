import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'stockfish_platform_interface.dart';

/// An implementation of [StockfishPlatform] that uses method channels.
class MethodChannelStockfish extends StockfishPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('stockfish');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
