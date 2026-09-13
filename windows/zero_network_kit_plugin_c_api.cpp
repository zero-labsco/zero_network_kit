#include "include/zero_network_kit/zero_network_kit_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "zero_network_kit_plugin.h"

void ZeroNetworkKitPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  zero_network_kit::ZeroNetworkKitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
