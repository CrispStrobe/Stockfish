#ifndef FLUTTER_PLUGIN_STOCKFISH_PLUGIN_H_
#define FLUTTER_PLUGIN_STOCKFISH_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace stockfish {

class StockfishPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  StockfishPlugin();

  virtual ~StockfishPlugin();

  // Disallow copy and assign.
  StockfishPlugin(const StockfishPlugin&) = delete;
  StockfishPlugin& operator=(const StockfishPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace stockfish

#endif  // FLUTTER_PLUGIN_STOCKFISH_PLUGIN_H_
