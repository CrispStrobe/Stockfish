import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;
    
    final cBuilder = CBuilder.library(
      name: packageName,
      assetName: '$packageName.dart',
      language: Language.cpp,
      sources: [
        'macos/src/ffi.cpp',
        'macos/src/stockfish/benchmark.cpp',
        'macos/src/stockfish/bitboard.cpp',
        'macos/src/stockfish/engine.cpp',
        'macos/src/stockfish/evaluate.cpp',
        'macos/src/stockfish/main.cpp',
        'macos/src/stockfish/memory.cpp',
        'macos/src/stockfish/misc.cpp',
        'macos/src/stockfish/movegen.cpp',
        'macos/src/stockfish/movepick.cpp',
        'macos/src/stockfish/position.cpp',
        'macos/src/stockfish/score.cpp',
        'macos/src/stockfish/search.cpp',
        'macos/src/stockfish/thread.cpp',
        'macos/src/stockfish/timeman.cpp',
        'macos/src/stockfish/tt.cpp',
        'macos/src/stockfish/uci.cpp',
        'macos/src/stockfish/ucioption.cpp',
        'macos/src/stockfish/tune.cpp',
        'macos/src/stockfish/syzygy/tbprobe.cpp',
        'macos/src/stockfish/nnue/nnue_misc.cpp',
        'macos/src/stockfish/nnue/network.cpp',
        'macos/src/stockfish/nnue/features/half_ka_v2_hm.cpp',
      ],
      flags: [
        '-std=c++17',
        '-pthread',
        '-fexceptions',
      ],
      defines: {
        'NNUE_EMBEDDING_OFF': '',
      },
      buildMode: BuildMode.debug,
      buildModeDefine: false,
      ndebugDefine: false,
      optimizationLevel: OptimizationLevel.o0,
    );
    await cBuilder.run(input: input, output: output);
  });
}