#include "include/zero_network_kit/zero_network_kit_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "zero_network_kit_plugin_private.h"

#define ZERO_NETWORK_KIT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), zero_network_kit_plugin_get_type(), \
                              ZeroNetworkKitPlugin))

struct _ZeroNetworkKitPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(ZeroNetworkKitPlugin, zero_network_kit_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void zero_network_kit_plugin_handle_method_call(
    ZeroNetworkKitPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "getNetworkDetails") == 0) {
    // A 档：桌面原生层只返回空详情 map，IP/IPv6 由 Dart NetworkInterface 兜底，
    // SSID / 网关 / MAC / VPN 在桌面为 null。
    g_autoptr(FlValue) result = fl_value_new_map();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void zero_network_kit_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(zero_network_kit_plugin_parent_class)->dispose(object);
}

static void zero_network_kit_plugin_class_init(ZeroNetworkKitPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = zero_network_kit_plugin_dispose;
}

static void zero_network_kit_plugin_init(ZeroNetworkKitPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  ZeroNetworkKitPlugin* plugin = ZERO_NETWORK_KIT_PLUGIN(user_data);
  zero_network_kit_plugin_handle_method_call(plugin, method_call);
}

void zero_network_kit_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  ZeroNetworkKitPlugin* plugin = ZERO_NETWORK_KIT_PLUGIN(
      g_object_new(zero_network_kit_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "zero_network_kit",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
