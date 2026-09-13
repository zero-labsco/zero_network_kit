# Platform Support / 平台支持

`zero_network_kit` is declared on **five** plugin platforms: Android, iOS,
macOS, Windows and Linux. **Web is not supported** — the Dart services rely on
`dart:io`, which does not compile for the web, and browsers have no raw
TCP/UDP sockets.

`zero_network_kit` 在 **五** 个插件平台上声明：Android、iOS、macOS、Windows 与
Linux。**不支持 Web**——Dart 服务依赖 `dart:io`（无法在 Web 上编译），且浏览器没有
原生 TCP/UDP 套接字。

## Capability matrix / 能力矩阵

| Capability | Android / iOS | Desktop (macOS / Windows / Linux) |
| --- | --- | --- |
| Connectivity (`connectivity_plus`) | ✅ | ✅ |
| Local IP / IPv6 (`NetworkInterface`) | ✅ | ✅ |
| Native details (SSID / gateway / MAC / VPN) | ✅ | ⚠️ see below |
| TCP ping | ✅ | ✅ |
| ICMP ping (`Process.run('ping')`) | ❌ | ✅ |
| HTTP ping | ✅ | ✅ |
| DNS system resolver | ✅ | ✅ |
| DNS raw UDP | ✅ | ✅ |
| Port check / scan | ✅ | ✅ |
| Speed test | ✅ | ✅ |
| Quality score | ✅ | ✅ |
| Benchmarks | ✅ | ✅ |

## `NetworkCapabilities` / 能力查询

Query the host platform before calling, so your UI can hide unsupported cards:

在调用前查询当前平台能力，UI 即可据此隐藏不支持的卡片：

```dart
final caps = NetworkDiagnostic.capabilities;
print(caps.platform);            // 'android' | 'ios' | 'macos' | 'windows' | 'linux'
print(caps.supports(NetworkCapability.nativeDetails)); // mobile: true, desktop: false
print(caps.supports(NetworkCapability.icmpPing));      // desktop: true, mobile: false
```

Rules baked into `NetworkCapabilities.current()`:

- `nativeDetails` is **mobile-only** (SSID / gateway / MAC / VPN need system APIs).
- `icmpPing` is **desktop-only** (uses the system `ping` binary).

`NetworkCapabilities.current()` 内置规则：

- `nativeDetails` **仅移动端**（SSID / 网关 / MAC / VPN 需要系统 API）。
- `icmpPing` **仅桌面**（使用系统 `ping` 命令）。

## Native details on desktop / 桌面原生详情

Desktop uses **tier A** by default: the native layer only reports the platform
version and an (often empty) details map. IP/IPv6 come from Dart
`NetworkInterface`. As a result:

桌面默认采用 **A 档**：原生层只报告平台版本与（通常为空的）详情 map，IP/IPv6 由 Dart
`NetworkInterface` 兜底。因此：

- **SSID / signal strength are always `null` on desktop.**
  **桌面上的 SSID / 信号强度恒为 `null`。**
- `gateway` / `macAddress` / `isVpn` are `null` on macOS and Linux.
  macOS 与 Linux 上 `gateway` / `macAddress` / `isVpn` 为 `null`。
- **Windows** additionally implements `GetAdaptersAddresses`, so it reports
  `gateway` / `macAddress` / DNS / `isVpn` (SSID still `null`). This is a bonus
  tier-B fragment kept as-is.
  **Windows** 额外实现了 `GetAdaptersAddresses`，因此上报 `gateway` / `macAddress` /
  DNS / `isVpn`（SSID 仍为 `null`）。这是保留的 B 档赠品。

Whatever the platform, a missing permission or an unreachable native call never
throws — the field simply stays `null` and the rest of the result still arrives.

无论在哪个平台，缺权限或原生调用不可达都**不会抛异常**——对应字段保持 `null`，其余
结果照常返回。

## Reading native data / 读取原生数据

```dart
final version = await ZeroNetworkKit.getPlatformVersion();
print(version); // e.g. 'Android 14' / 'iOS 18.0'

final details = await ZeroNetworkKit.getNativeNetworkDetails();
if (details != null) {
  print(details); // SSID, BSSID, gateway, MAC, VPN flag, RSSI …
}
```
