import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../zero_network_kit_platform_interface.dart';
import '../models/network_connection_info.dart';
import '../models/network_type.dart';

/// 连接类型数据源抽象 / Abstraction over the platform connectivity source.
///
/// 默认由 `connectivity_plus` 实现，单元测试可注入假实现 /
/// Implemented by `connectivity_plus` by default; unit tests can inject fakes.
abstract class ConnectivityAdapter {
  /// 读取当前连接类型（如 `['wifi']`）/ Reads the current transports, e.g.
  /// `['wifi']`.
  Future<List<String>> checkConnectivity();

  /// 监听连接类型变化 / Emits whenever the transports change.
  Stream<List<String>> get onConnectivityChanged;
}

/// 基于 `connectivity_plus` 的默认适配器 /
/// Default adapter backed by `connectivity_plus`.
class ConnectivityPlusAdapter implements ConnectivityAdapter {
  /// 构造 [ConnectivityPlusAdapter] / Creates a [ConnectivityPlusAdapter].
  ConnectivityPlusAdapter([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<String>> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _names(results);
  }

  @override
  Stream<List<String>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_names);

  List<String> _names(List<ConnectivityResult> results) =>
      results.map((result) => result.name).toList(growable: false);
}

/// 连通性检测与网络信息采集服务 /
/// Connectivity detection and network information service.
class ConnectivityService {
  /// 构造 [ConnectivityService] / Creates a [ConnectivityService].
  ConnectivityService({ConnectivityAdapter? adapter})
    : _adapter = adapter ?? ConnectivityPlusAdapter();

  final ConnectivityAdapter _adapter;

  /// 主动可达性探测实现 / Reachability probe used when explicitly requested.
  ///
  /// 默认通过系统解析器查询 `one.one.one.one` / Defaults to resolving
  /// `one.one.one.one` through the platform resolver.
  Future<bool> Function() reachabilityProbe = _defaultReachabilityProbe;

  /// 采集一次网络连接快照 / Captures one network connection snapshot.
  ///
  /// [includeNativeDetails] 为 `true` 时会调用原生通道获取 SSID、网关、MAC 等
  /// 信息（失败时静默降级）/ When [includeNativeDetails] is `true` an extra
  /// platform-channel call enriches the snapshot with SSID, gateway and MAC
  /// (silently degrades on failure).
  /// [probeReachability] 为 `true` 时会额外执行主动连通性探测 /
  /// [probeReachability] additionally performs an active reachability probe.
  Future<NetworkConnectionInfo> checkConnection({
    bool includeNativeDetails = true,
    bool probeReachability = false,
    Duration probeTimeout = const Duration(seconds: 3),
  }) async {
    final transports = await _safeTransports();
    final types = transports
        .map(NetworkType.fromRaw)
        .where((type) => type != NetworkType.none)
        .toList(growable: false);

    Map<String, Object?>? native;
    if (includeNativeDetails) {
      native = await _safeNativeDetails();
    }

    final fallback = await _dartInterfaceSnapshot();

    final ipAddress =
        _asString(native?['ipAddress']) ??
        fallback.ipAddress ??
        _asString(native?['ipv6Address']) ??
        fallback.ipv6Address;

    final info = NetworkConnectionInfo(
      isConnected: types.isNotEmpty || ipAddress != null,
      type: _resolveType(types),
      ssid: _asString(native?['ssid']),
      signalStrength: (native?['signalStrength'] as num?)?.toInt(),
      ipAddress: _asString(native?['ipAddress']) ?? fallback.ipAddress,
      ipv6Address: _asString(native?['ipv6Address']) ?? fallback.ipv6Address,
      gateway: _asString(native?['gateway']),
      macAddress: _asString(native?['macAddress']),
      isVpn: native?['isVpn'] == true || types.contains(NetworkType.vpn),
      timestamp: DateTime.now(),
    );

    if (!probeReachability) return info;
    return info.copyWith(isReachable: await _safeProbe(probeTimeout));
  }

  /// 监听网络连接变化 / Emits a fresh snapshot whenever connectivity changes.
  ///
  /// 立即发出一次当前状态，随后在每次底层变化时重新采集 /
  /// Emits the current state immediately, then re-samples on every change.
  Stream<NetworkConnectionInfo> get onConnectivityChanged async* {
    yield await checkConnection();
    await for (final _ in _adapter.onConnectivityChanged) {
      yield await checkConnection();
    }
  }

  Future<List<String>> _safeTransports() async {
    try {
      return await _adapter.checkConnectivity();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<Map<String, Object?>?> _safeNativeDetails() async {
    try {
      return await ZeroNetworkKitPlatform.instance.getNetworkDetails();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _safeProbe(Duration timeout) async {
    try {
      return await reachabilityProbe().timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  /// 从连通性结果中挑出最具代表性的传输类型 /
  /// Picks the most representative transport from the raw results.
  static NetworkType _resolveType(List<NetworkType> types) {
    const priority = <NetworkType>[
      NetworkType.wifi,
      NetworkType.ethernet,
      NetworkType.mobile,
      NetworkType.bluetooth,
      NetworkType.other,
      NetworkType.vpn,
    ];
    for (final candidate in priority) {
      if (types.contains(candidate)) return candidate;
    }
    return NetworkType.none;
  }

  /// 通过 `dart:io` 读取 IP / IPv6 / MAC 作为跨平台兜底 /
  /// Reads IP, IPv6 and MAC through `dart:io` as a cross-platform fallback.
  static Future<_InterfaceSnapshot> _dartInterfaceSnapshot() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );

      _InterfaceSnapshot snapshot = const _InterfaceSnapshot();
      for (final interface in interfaces) {
        final ipv4 = _firstOf(interface.addresses, InternetAddressType.IPv4);
        final ipv6 = _firstOf(interface.addresses, InternetAddressType.IPv6);
        final candidate = _InterfaceSnapshot(
          ipAddress: ipv4,
          ipv6Address: ipv6,
        );
        if (snapshot.ipAddress == null) {
          snapshot = candidate;
        }
        // 优先保留带 IPv4 的接口 / Prefer an interface that owns an IPv4.
        if (ipv4 != null && interface.name != 'lo') break;
      }
      return snapshot;
    } catch (_) {
      return const _InterfaceSnapshot();
    }
  }

  static String? _firstOf(
    List<InternetAddress> addresses,
    InternetAddressType type,
  ) {
    for (final address in addresses) {
      if (address.type == type) {
        final raw = address.address;
        return type == InternetAddressType.IPv6 ? raw.split('%').first : raw;
      }
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Future<bool> _defaultReachabilityProbe() async {
    final addresses = await InternetAddress.lookup('one.one.one.one');
    return addresses.isNotEmpty;
  }
}

/// `dart:io` 网卡快照 / Snapshot derived from `dart:io` network interfaces.
///
/// `dart:io` 不暴露 MAC 地址，该字段只能由原生通道提供 /
/// `dart:io` does not expose the MAC address, so it can only come from the
/// native channel.
class _InterfaceSnapshot {
  const _InterfaceSnapshot({this.ipAddress, this.ipv6Address});

  final String? ipAddress;
  final String? ipv6Address;
}
