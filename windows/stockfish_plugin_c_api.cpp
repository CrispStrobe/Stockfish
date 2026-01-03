#include "include/stockfish/stockfish_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "stockfish_plugin.h"

void StockfishPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  stockfish::StockfishPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
