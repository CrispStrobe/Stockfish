import 'dart:ffi';
import 'package:ffi/ffi.dart';

@Native<Int32 Function()>(symbol: 'stockfish_init', assetId: 'package:stockfish/stockfish.dart')
external int nativeInit();

@Native<Int32 Function()>(symbol: 'stockfish_main', assetId: 'package:stockfish/stockfish.dart')
external int nativeMain();

@Native<IntPtr Function(Pointer<Utf8>)>(symbol: 'stockfish_stdin_write', assetId: 'package:stockfish/stockfish.dart')
external int nativeStdinWrite(Pointer<Utf8> data);

@Native<Pointer<Utf8> Function()>(symbol: 'stockfish_stdout_read', assetId: 'package:stockfish/stockfish.dart')
external Pointer<Utf8> nativeStdoutRead();