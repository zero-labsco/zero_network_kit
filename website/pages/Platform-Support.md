# Platform Support / 平台支持

`zero_network_kit` is declared on **six** plugin platforms: Android, iOS,
macOS, Windows, Linux and **Web**. Web support is **partial**: the services that
depend on `dart:io` are swapped for browser-safe equivalents, and the
capabilities the sandbox forbids degrade gracefully instead of failing.

`zero_network_kit` 在 **六** 个插件平台上声明：Android、iOS、macOS、Windows、Linux
与 **Web**。Web 为**部分支持**：依赖 `dart:io` 的服务已替换为浏览器安全的等价实现，
浏览器沙箱禁止的能力会优雅降级而不会失败。

## Capability matrix / 能力矩阵

| Capability | Android | iOS | Desktop (macOS / Windows / Linux) | Web |
| --- | --- | --- | --- | --- |
| Connectivity | ✅ | ✅ | ✅ | ✅ `navigator.onLine` |
| Local IP / IPv6 (`NetworkInterface`) | ✅ | ✅ | ✅ | ❌ |
| Native details — IP / IPv6 / VPN | ✅ | ✅ | ✅ macOS, Windows · ❌ Linux | ❌ |
| Native details — gateway | ✅ | ✅ | ✅ Windows, macOS · ❌ Linux | ❌ |
| Native details — MAC | ✅ | ❌ | ✅ Windows · ❌ macOS, Linux | ❌ |
| Native details — SSID / BSSID / RSSI | ✅ permission required | ❌ | ❌ | ❌ |
| TCP ping | ✅ | ✅ | ✅ | ⚠️ HTTPS round trip |
| ICMP ping (`Process.run('ping')`) | ❌ | ✅ | ❌ |
| HTTP ping | ✅ | ✅ | ✅ |
| DNS system resolver | ✅ | ✅ | ✅ DoH |
| DNS raw UDP | ✅ | ✅ | ⚠️ DoH endpoint required |
| Port check / scan | ✅ | ✅ | ❌ |
| Speed test | ✅ | ✅ | ✅ |
| Quality score | ✅ | ✅ | ✅ |
| Benchmarks | ✅ | ✅ | ✅ |

## `NetworkCapabilities` / 能力查询

Query the host platform before calling, so your UI can hide unsupported cards:

在调用前查询当前平台能力，UI 即可据此隐藏不支持的卡片：

```dart
final caps = NetworkDiagnostic.capabilities;
print(caps.platform);            // 'android' | 'ios' | 'macos' | 'windows' | 'linux' | 'web'
print(caps.supports(NetworkCapability.nativeDetails)); // mobile: true, desktop: false
print(caps.supports(NetworkCapability.wifiDetails));   // Android: true, everywhere else: false
print(caps.supports(NetworkCapability.icmpPing));      // desktop: true, mobile: false
```

Rules baked into `NetworkCapabilities.current()`:

- `wifiDetails` (SSID / BSSID / RSSI) is **Android-only** — iOS does not request
  the *Access WiFi Information* capability, so those fields are always `null`
  there. On Android they additionally need a runtime permission grant.
- `nativeDetails` (IP / IPv6 / VPN) is **mobile-only**.
- `icmpPing` is **desktop-only** (uses the system `ping` binary).
- On **web** the supported set narrows to `connectivity`, `tcpPing`,
  `dnsSystem`, `speedTest`, `quality` and `benchmark`; every other capability is
  absent.

`NetworkCapabilities.current()` 内置规则：

- `wifiDetails`（SSID / BSSID / 信号强度）**仅 Android** —— iOS 未申请
  *Access WiFi Information* 能力，这些字段在 iOS 上恒为 `null`；Android 上还需运行时授权。
- `nativeDetails`（IP / IPv6 / VPN）**仅移动端**。
- `icmpPing` **仅桌面**（使用系统 `ping` 命令）。
- **Web** 上的支持集合收缩为 `connectivity`、`tcpPing`、`dnsSystem`、`speedTest`、
  `quality` 与 `benchmark`，其余能力均不存在。

## Native details on desktop / 桌面原生详情

Desktop never reports Wi-Fi details, and the three desktop platforms differ in
how much else they expose:

桌面端从不提供 Wi-Fi 详情，三个桌面平台在其余字段上也各不相同：

- **SSID / BSSID / signal strength are always `null` on desktop.**
  **桌面上的 SSID / BSSID / 信号强度恒为 `null`。**
- **Windows** implements `GetAdaptersAddresses`, so it reports `ipAddress` /
  `ipv6Address` / `gateway` / `macAddress` / DNS / `isVpn`.
  **Windows** 实现了 `GetAdaptersAddresses`，因此上报 `ipAddress` / `ipv6Address` /
  `gateway` / `macAddress` / DNS / `isVpn`。
- **macOS** shares the Darwin implementation with iOS, so it reports
  `ipAddress` / `ipv6Address` / `gateway` / `isVpn`.
  **macOS** 与 iOS 共用 Darwin 实现，因此上报 `ipAddress` / `ipv6Address` /
  `gateway` / `isVpn`。
- `gateway` is read from the `sysctl` routing table (the same source as
  `netstat -rn`), which needs **no permission and no entitlement** — so it is
  available on Android, iOS, macOS and Windows.
  `gateway` 从 `sysctl` 路由表读取（与 `netstat -rn` 同源），**不需要任何权限或
  entitlement**，因此在 Android、iOS、macOS 与 Windows 上都可用。
- **Linux** returns an empty details map; IP/IPv6 come from Dart
  `NetworkInterface`.
  **Linux** 返回空详情 map，IP/IPv6 由 Dart `NetworkInterface` 兜底。

Whatever the platform, a missing permission or an unreachable native call never
throws — the field simply stays `null` and the rest of the result still arrives.

无论在哪个平台，缺权限或原生调用不可达都**不会抛异常**——对应字段保持 `null`，其余
结果照常返回。

## Web support / Web 支持

The web build exposes the same static API. Capabilities that the browser sandbox
forbids degrade gracefully — they return `null` or an "unavailable" result
instead of throwing:

| Capability | Web | Notes |
| --- | --- | --- |
| Connectivity | ✅ | via the browser's `navigator.onLine` |
| Ping (`PingMode.tcp`) | ⚠️ | measured as an HTTPS round trip; the target must send CORS headers |
| Ping (`PingMode.icmp`) | ❌ | throws `UnsupportedError` |
| DNS (system resolver) | ✅ | via DNS-over-HTTPS |
| DNS (explicit server) | ⚠️ | needs a DoH endpoint, otherwise "unsupported" |
| Speed test | ✅ | HTTP download / upload |
| Quality score | ✅ | pure function |
| Benchmarks | ✅ | pure function |
| Port check / scan | ❌ | returns "unavailable" results |
| Native details (SSID, gateway, MAC, VPN) | ❌ | `null` |

Browsers expose **no VPN API**, so `isVpn` stays `false` on the web even when a
system VPN or a local HTTP proxy is active.

Web 构建提供同样的静态 API；浏览器沙箱禁止的能力会优雅降级（返回 `null` 或"不可用"
结果，而不是抛异常）：

| 能力 | Web | 说明 |
| --- | --- | --- |
| 连通性检测 | ✅ | 通过浏览器的 `navigator.onLine` |
| Ping（`PingMode.tcp`） | ⚠️ | 以 HTTPS 往返耗时度量，目标主机需下发 CORS 头 |
| Ping（`PingMode.icmp`） | ❌ | 抛出 `UnsupportedError` |
| DNS（系统解析器） | ✅ | 通过 DNS-over-HTTPS |
| DNS（指定服务器） | ⚠️ | 需要 DoH 端点，否则返回"不支持" |
| 带宽测速 | ✅ | HTTP 下载 / 上传 |
| 质量评分 | ✅ | 纯函数 |
| 基准测试 | ✅ | 纯函数 |
| 端口检测 / 扫描 | ❌ | 返回"不可用"结果 |
| 原生详情（SSID、网关、MAC、VPN） | ❌ | 返回 `null` |

浏览器**不暴露 VPN 接口**，因此即使系统开启了 VPN 或本地 HTTP 代理，Web 上的
`isVpn` 仍为 `false`。

## Reading native data / 读取原生数据

```dart
final version = await ZeroNetworkKit.getPlatformVersion();
print(version); // e.g. 'Android 14' / 'iOS 18.0' / 'Web'

final details = await ZeroNetworkKit.getNativeNetworkDetails();
if (details != null) {
  print(details); // SSID, BSSID, gateway, MAC, VPN flag, RSSI …
}
```

`details` is always `null` on the web and on Linux; macOS and Windows populate it
partially (see above).

Web 与 Linux 上 `details` 恒为 `null`；macOS 与 Windows 会填充其中一部分字段（见上文）。
