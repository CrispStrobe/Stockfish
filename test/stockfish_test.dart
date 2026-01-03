import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish/stockfish.dart';
import 'package:stockfish/stockfish_platform_interface.dart';
import 'package:stockfish/stockfish_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockStockfishPlatform
    with MockPlatformInterfaceMixin
    implements StockfishPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final StockfishPlatform initialPlatform = StockfishPlatform.instance;

  test('$MethodChannelStockfish is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelStockfish>());
  });

  test('getPlatformVersion', () async {
    Stockfish stockfishPlugin = Stockfish();
    MockStockfishPlatform fakePlatform = MockStockfishPlatform();
    StockfishPlatform.instance = fakePlatform;

    expect(await stockfishPlugin.getPlatformVersion(), '42');
  });
}
