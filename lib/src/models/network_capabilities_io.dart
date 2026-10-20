import 'dart:io';

/// 单项网络诊断能力 / A single network diagnostic capability.
enum NetworkCapability {
  /// 连通性检测 / Connectivity check.
  connectivity,

  /// 原生网络详情（IP / IPv6 / VPN 等）/ Native details (IP / IPv6 / VPN …).
  nativeDetails,

  /// Wi-Fi 详情（SSID / BSSID / 信号强度）/ Wi-Fi details (SSID / BSSID / RSSI).
  ///
  /// 仅 Android 原生层真正读取这些字段：iOS 未申请 *Access WiFi Information*
  /// 能力，桌面与 Web 均不提供，故这些平台上对应字段恒为 `null` / Only the
  /// Android native layer actually reads them: iOS does not request the
  /// *Access WiFi Information* capability and desktop / web never provide them,
  /// so the fields stay `null` there.
  wifiDetails,

  /// 本地 IP / IPv6 快照 / Local address snapshot.
  localAddresses,

  /// TCP 握手延迟 / TCP handshake latency.
  tcpPing,

  /// 系统 ICMP `ping` 命令（仅桌面）/ System ICMP ping (desktop only).
  icmpPing,

  /// 系统 DNS 解析器 / System DNS resolver.
  dnsSystem,

  /// 指定服务器的原始 UDP DNS 查询 / Raw UDP DNS against an explicit server.
  dnsUdp,

  /// TCP 端口检测 / TCP port check.
  portCheck,

  /// 带宽测速 / Bandwidth speed test.
  speedTest,

  /// 质量评分 / Quality scoring.
  quality,

  /// 微基准 / Micro-benchmarks.
  benchmark,
}

/// 当前平台支持的网络能力集合 / The set of capabilities on the current platform.
class NetworkCapabilities {
  /// 构造 [NetworkCapabilities] / Creates a [NetworkCapabilities].
  const NetworkCapabilities({required this.supported, required this.platform});

  /// 当前平台支持的能力 / Capabilities available on the current platform.
  final Set<NetworkCapability> supported;

  /// 平台标识 / Platform identifier.
  final String platform;

  /// 该能力是否可用 / Whether [capability] is available.
  bool supports(NetworkCapability capability) => supported.contains(capability);

  /// 基于当前运行平台构建能力集 / Builds the capability set for the host platform.
  ///
  /// [NetworkCapability.nativeDetails] 按**平台实际是否产出原生详情**判定，而不是
  /// 按「是否移动端」：macOS 与 Windows 的原生层同样返回 IP / IPv6 / 网关 / VPN
  /// （Windows 还提供 MAC 与 DNS），只有 Linux 的 `getNetworkDetails` 返回空 map。
  /// 此前把它限定为「仅移动端」，会让 macOS / Windows 上真实有值的字段被 UI 隐藏 /
  /// [NetworkCapability.nativeDetails] reflects whether the native layer actually
  /// produces details, not whether the platform is mobile: macOS and Windows also
  /// return IP / IPv6 / gateway / VPN (Windows adds MAC and DNS), and only Linux
  /// answers `getNetworkDetails` with an empty map. Restricting it to mobile made
  /// UIs hide fields that do carry values on macOS / Windows.
  /// [NetworkCapability.icmpPing] 仅桌面可用 / [icmpPing] is desktop-only.
  static NetworkCapabilities current() {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : Platform.isMacOS
        ? 'macos'
        : Platform.isWindows
        ? 'windows'
        : Platform.isLinux
        ? 'linux'
        : 'unknown';

    final supported = <NetworkCapability>{
      NetworkCapability.connectivity,
      NetworkCapability.localAddresses,
      NetworkCapability.tcpPing,
      NetworkCapability.dnsSystem,
      NetworkCapability.dnsUdp,
      NetworkCapability.portCheck,
      NetworkCapability.speedTest,
      NetworkCapability.quality,
      NetworkCapability.benchmark,
    };
    // 移动端 + macOS + Windows 都会产出原生详情，只有 Linux 返回空 map /
    // Mobile plus macOS and Windows all produce native details; only Linux
    // answers with an empty map.
    if (isMobile || Platform.isMacOS || Platform.isWindows) {
      supported.add(NetworkCapability.nativeDetails);
    }
    if (isDesktop) supported.add(NetworkCapability.icmpPing);
    // 只有 Android 原生层读取 SSID / BSSID / RSSI / Only the Android native
    // layer reads SSID / BSSID / RSSI.
    if (Platform.isAndroid) supported.add(NetworkCapability.wifiDetails);

    return NetworkCapabilities(supported: supported, platform: platform);
  }
}
