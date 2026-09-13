import 'dart:io';

/// 单项网络诊断能力 / A single network diagnostic capability.
enum NetworkCapability {
  /// 连通性检测 / Connectivity check.
  connectivity,

  /// 原生网络详情（SSID / 网关 / MAC / VPN）/ Native details.
  nativeDetails,

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
  /// 桌面（A 档）不保证原生详情，故 [NetworkCapability.nativeDetails] 仅移动端纳入；
  /// [NetworkCapability.icmpPing] 反之仅桌面可用 /
  /// Desktops (tier A) cannot reliably provide native details, so [nativeDetails]
  /// is mobile-only; [icmpPing] is desktop-only.
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
    if (isMobile) supported.add(NetworkCapability.nativeDetails);
    if (isDesktop) supported.add(NetworkCapability.icmpPing);

    return NetworkCapabilities(supported: supported, platform: platform);
  }
}
