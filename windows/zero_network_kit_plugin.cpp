// winsock2.h must be included before windows.h, and the Flutter headers below
// pull windows.h in transitively, so this has to stay the very first include.
#include <winsock2.h>

#include "zero_network_kit_plugin.h"

// Pull in the public header so the C registration entry point is declared with
// FLUTTER_PLUGIN_EXPORT (resolved to dllexport under FLUTTER_PLUGIN_IMPL).
#include "include/zero_network_kit/zero_network_kit_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter_plugin_registrar.h>

// For the version fallback in WindowsVersionString.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <iphlpapi.h>
#include <ws2tcpip.h>

#include <cstdlib>
#include <iomanip>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace zero_network_kit {

namespace {

/// 十六进制 MAC 地址的字节数 / Number of bytes in a hardware address.
constexpr ULONG kMacAddressBytes = 6;

/// Flutter 标准通道传输 UTF-8 字符串 / The standard codec transports UTF-8.
std::string WideToUtf8(const wchar_t* value) {
  if (value == nullptr) return std::string();

  const int size =
      WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) return std::string();

  std::string output(static_cast<size_t>(size), '\0');
  const int written = WideCharToMultiByte(CP_UTF8, 0, value, -1, &output[0],
                                          size, nullptr, nullptr);
  if (written <= 0) return std::string();

  output.resize(static_cast<size_t>(written - 1));
  return output;
}

/// 把 socket 地址格式化为可读字符串，去掉 IPv6 的 scope 后缀 /
/// Formats a socket address as text, without the IPv6 scope suffix.
std::string AddressToString(const SOCKET_ADDRESS& socket_address) {
  if (socket_address.lpSockaddr == nullptr) return std::string();

  char host[NI_MAXHOST] = {};
  const int status = getnameinfo(
      socket_address.lpSockaddr,
      static_cast<socklen_t>(socket_address.iSockaddrLength), host, NI_MAXHOST,
      nullptr, 0, NI_NUMERICHOST);
  if (status != 0) return std::string();

  std::string text(host);
  const size_t scope = text.find('%');
  if (scope != std::string::npos) text.resize(scope);
  return text;
}

/// 把网卡物理地址格式化为 `aa:bb:cc:dd:ee:ff` /
/// Formats a hardware address as `aa:bb:cc:dd:ee:ff`.
std::string FormatMacAddress(const IP_ADAPTER_ADDRESSES* adapter) {
  if (adapter->PhysicalAddressLength != kMacAddressBytes) return std::string();

  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (ULONG index = 0; index < kMacAddressBytes; ++index) {
    if (index > 0) stream << ':';
    stream << std::setw(2)
           << static_cast<int>(adapter->PhysicalAddress[index]);
  }
  return stream.str();
}

/// 单块网卡的快照 / Snapshot of a single adapter.
struct AdapterSnapshot {
  std::string ipv4;
  std::string ipv6;
  std::string gateway;
  std::string mac;
  std::string dns;
};

/// 读取一块网卡的地址信息 / Reads the addresses of a single adapter.
AdapterSnapshot SnapshotFor(const IP_ADAPTER_ADDRESSES* adapter) {
  AdapterSnapshot snapshot;

  for (auto* unicast = adapter->FirstUnicastAddress; unicast != nullptr;
       unicast = unicast->Next) {
    const SOCKET_ADDRESS& address = unicast->Address;
    if (address.lpSockaddr == nullptr) continue;

    if (address.lpSockaddr->sa_family == AF_INET && snapshot.ipv4.empty()) {
      snapshot.ipv4 = AddressToString(address);
    } else if (address.lpSockaddr->sa_family == AF_INET6 &&
               snapshot.ipv6.empty()) {
      snapshot.ipv6 = AddressToString(address);
    }
  }

  for (auto* gateway = adapter->FirstGatewayAddress; gateway != nullptr;
       gateway = gateway->Next) {
    if (gateway->Address.lpSockaddr == nullptr) continue;
    if (gateway->Address.lpSockaddr->sa_family != AF_INET) continue;

    snapshot.gateway = AddressToString(gateway->Address);
    if (!snapshot.gateway.empty()) break;
  }

  for (auto* server = adapter->FirstDnsServerAddress; server != nullptr;
       server = server->Next) {
    if (server->Address.lpSockaddr == nullptr) continue;

    snapshot.dns = AddressToString(server->Address);
    if (!snapshot.dns.empty()) break;
  }

  snapshot.mac = FormatMacAddress(adapter);
  return snapshot;
}

/// 读取 Windows 版本字符串，例如 `Windows 11 (build 22631)` /
/// Reads the Windows version string, e.g. `Windows 11 (build 22631)`.
///
/// `GetVersionEx` 在未声明清单的应用上会谎报版本，因此这里直接读取注册表 /
/// `GetVersionEx` reports a fixed version for apps without a manifest, so the
/// registry is read directly instead.
std::string WindowsVersionString() {
  std::string major_text;
  std::string minor_text;
  std::string build_text;

  HKEY key = nullptr;
  const LONG opened = RegOpenKeyExW(
      HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
      0, KEY_READ | KEY_WOW64_64KEY, &key);

  if (opened == ERROR_SUCCESS) {
    const wchar_t* names[] = {L"CurrentMajorVersionNumber",
                              L"CurrentMinorVersionNumber",
                              L"CurrentBuildNumber"};
    std::string* targets[] = {&major_text, &minor_text, &build_text};

    for (int index = 0; index < 3; ++index) {
      DWORD type = 0;
      DWORD size = 0;
      if (RegQueryValueExW(key, names[index], nullptr, &type, nullptr, &size) !=
              ERROR_SUCCESS ||
          size == 0) {
        continue;
      }

      if (type == REG_DWORD && size == sizeof(DWORD)) {
        DWORD value = 0;
        if (RegQueryValueExW(key, names[index], nullptr, &type,
                             reinterpret_cast<LPBYTE>(&value), &size) ==
            ERROR_SUCCESS) {
          std::ostringstream stream;
          stream << value;
          *targets[index] = stream.str();
        }
      } else if (type == REG_SZ || type == REG_EXPAND_SZ) {
        std::vector<wchar_t> raw(size / sizeof(wchar_t) + 1, L'\0');
        if (RegQueryValueExW(key, names[index], nullptr, &type,
                             reinterpret_cast<LPBYTE>(raw.data()), &size) ==
            ERROR_SUCCESS) {
          *targets[index] = WideToUtf8(raw.data());
        }
      }
    }
    RegCloseKey(key);
  }

  if (major_text.empty() || build_text.empty()) {
    // 注册表不可读时退回版本辅助函数 / Fall back to the version helpers.
    if (IsWindows10OrGreater()) return "Windows 10+";
    if (IsWindows8OrGreater()) return "Windows 8";
    if (IsWindows7OrGreater()) return "Windows 7";
    return "Windows";
  }

  const int major = std::atoi(major_text.c_str());
  const int build = std::atoi(build_text.c_str());

  std::ostringstream version;
  version << "Windows ";
  if (major >= 10) {
    version << (build >= 22000 ? "11" : "10");
  } else {
    version << major_text;
    if (!minor_text.empty()) version << '.' << minor_text;
  }
  version << " (build " << build_text << ')';
  return version.str();
}

/// 已知 VPN 驱动在网卡描述里出现的关键字 /
/// Substrings identifying well-known VPN drivers in an adapter description.
const char* const kVpnDescriptionKeywords[] = {
    "tap-windows", "wintun",    "wireguard", "openvpn",
    "anyconnect",  "softether", "tailscale", "zerotier",
    "nordlynx",    "mullvad",   "fortissl",  "globalprotect"};

/// 判断一块网卡是否属于 VPN / Decides whether an adapter belongs to a VPN.
///
/// `IF_TYPE_TUNNEL` 覆盖 IKEv2 / SSTP / L2TP 等系统内置 VPN。不能把
/// `IF_TYPE_PPP` 一律视为 VPN：PPPoE 宽带拨号同样是 PPP，会大规模误判。
/// 而 TAP-Windows / Wintun / OpenVPN 这类适配器不按隧道类型上报，只能依据网卡
/// 描述里的驱动名识别 /
/// `IF_TYPE_TUNNEL` covers the built-in IKEv2 / SSTP / L2TP VPNs.
/// `IF_TYPE_PPP` cannot be treated as a VPN unconditionally: PPPoE broadband is
/// PPP as well and would be misreported on a large scale. TAP-Windows / Wintun /
/// OpenVPN adapters do not report as tunnels, so they are recognised from the
/// driver name in the adapter description instead.
bool IsVpnAdapter(const IP_ADAPTER_ADDRESSES* adapter) {
  if (adapter->IfType == IF_TYPE_TUNNEL) return true;

  std::string description = WideToUtf8(adapter->Description);
  for (char& character : description) {
    if (character >= 'A' && character <= 'Z') {
      character = static_cast<char>(character - 'A' + 'a');
    }
  }

  for (const char* keyword : kVpnDescriptionKeywords) {
    if (description.find(keyword) != std::string::npos) return true;
  }
  return false;
}

/// 汇总当前激活网络的属性 / Collects the properties of the active network.
///
/// 活跃网卡由「是否拥有默认网关」优先决定，其次才看遍历顺序 /
/// The active adapter is chosen by "owns a default gateway" first, then by
/// enumeration order.
flutter::EncodableMap CollectNetworkDetails() {
  flutter::EncodableMap details;

  ULONG buffer_size = 16 * 1024;
  std::vector<BYTE> buffer(buffer_size);

  const ULONG flags = GAA_FLAG_INCLUDE_GATEWAYS | GAA_FLAG_SKIP_ANYCAST |
                      GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_FRIENDLY_NAME;

  ULONG status = GetAdaptersAddresses(
      AF_UNSPEC, flags, nullptr,
      reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data()), &buffer_size);
  if (status == ERROR_BUFFER_OVERFLOW) {
    buffer.resize(buffer_size);
    status = GetAdaptersAddresses(
        AF_UNSPEC, flags, nullptr,
        reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data()), &buffer_size);
  }
  if (status != ERROR_SUCCESS) return details;

  AdapterSnapshot best;
  bool has_best = false;
  bool best_has_gateway = false;
  bool vpn_detected = false;

  for (auto* adapter = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
       adapter != nullptr; adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp) continue;
    if (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK) continue;
    if (IsVpnAdapter(adapter)) {
      vpn_detected = true;
      continue;
    }

    const AdapterSnapshot candidate = SnapshotFor(adapter);
    if (candidate.ipv4.empty() && candidate.ipv6.empty()) continue;

    const bool has_gateway = !candidate.gateway.empty();
    if (!has_best || (has_gateway && !best_has_gateway)) {
      best = candidate;
      best_has_gateway = has_gateway;
      has_best = true;
    }
  }

  if (!best.ipv4.empty()) {
    details[flutter::EncodableValue("ipAddress")] =
        flutter::EncodableValue(best.ipv4);
  }
  if (!best.ipv6.empty()) {
    details[flutter::EncodableValue("ipv6Address")] =
        flutter::EncodableValue(best.ipv6);
  }
  if (!best.gateway.empty()) {
    details[flutter::EncodableValue("gateway")] =
        flutter::EncodableValue(best.gateway);
  }
  if (!best.mac.empty()) {
    details[flutter::EncodableValue("macAddress")] =
        flutter::EncodableValue(best.mac);
  }
  if (!best.dns.empty()) {
    details[flutter::EncodableValue("dnsServer")] =
        flutter::EncodableValue(best.dns);
  }
  details[flutter::EncodableValue("isVpn")] =
      flutter::EncodableValue(vpn_detected);

  return details;
}

}  // namespace

// static
void ZeroNetworkKitPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "zero_network_kit",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ZeroNetworkKitPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ZeroNetworkKitPlugin::ZeroNetworkKitPlugin() {}

ZeroNetworkKitPlugin::~ZeroNetworkKitPlugin() {}

void ZeroNetworkKitPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    result->Success(flutter::EncodableValue(WindowsVersionString()));
  } else if (method_call.method_name().compare("getNetworkDetails") == 0) {
    result->Success(flutter::EncodableValue(CollectNetworkDetails()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace zero_network_kit

// C entry point used by the generated plugin registrant on Windows. Bridges the
// C registrar reference to the C++ plugin implementation.
// 供 Windows 端注册器调用的 C 入口，桥接到 C++ 插件实现。
FLUTTER_PLUGIN_EXPORT void ZeroNetworkKitPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  zero_network_kit::ZeroNetworkKitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
