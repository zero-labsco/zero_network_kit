#ifndef FLUTTER_PLUGIN_ZERO_NETWORK_KIT_PLUGIN_PUBLIC_H_
#define FLUTTER_PLUGIN_ZERO_NETWORK_KIT_PLUGIN_PUBLIC_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Registers the plugin with the given registrar. Invoked by the generated
// plugin registrant on Windows.
// 由 Windows 端自动生成的注册器调用，完成插件注册。
FLUTTER_PLUGIN_EXPORT void ZeroNetworkKitPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_ZERO_NETWORK_KIT_PLUGIN_PUBLIC_H_
