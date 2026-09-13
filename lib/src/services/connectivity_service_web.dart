import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

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

/// Web 端连通性检测与网络信息采集服务 /
/// Connectivity detection and network information service for the web platform.
///
/// 浏览器无法枚举网卡（无 `dart:io`），因此 IP / 网关 / MAC 等字段恒为 `null`；
/// 主动可达性探测改为对公共端点发起 HTTP 请求 /
/// Browsers cannot enumerate network interfaces (no `dart:io`), so IP / gateway /
/// MAC fields are always `null`; the reachability probe performs an HTTP request
/// against a public endpoint instead.
class ConnectivityService {
  /// 构造 [ConnectivityService] / Creates a [ConnectivityService].
  ConnectivityService({ConnectivityAdapter? adapter})
    : _adapter = adapter ?? ConnectivityPlusAdapter();

  final ConnectivityAdapter _adapter;

  /// 主动可达性探测实现 / Reachability probe used when explicitly requested.
  ///
  /// Web 端通过 HTTP 请求公共端点来判定连通性 /
  /// On the web a public endpoint is probed over HTTP to decide reachability.
  Future<bool> Function() reachabilityProbe = _defaultReachabilityProbe;

  /// 采集一次网络连接快照 / Captures one network connection snapshot.
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

    final info = NetworkConnectionInfo(
      isConnected: types.isNotEmpty,
      type: _resolveType(types),
      ssid: _asString(native?['ssid']),
      signalStrength: (native?['signalStrength'] as num?)?.toInt(),
      ipAddress: _asString(native?['ipAddress']),
      ipv6Address: _asString(native?['ipv6Address']),
      gateway: _asString(native?['gateway']),
      macAddress: _asString(native?['macAddress']),
      isVpn: native?['isVpn'] == true || types.contains(NetworkType.vpn),
      timestamp: DateTime.now(),
    );

    if (!probeReachability) return info;
    return info.copyWith(isReachable: await _safeProbe(probeTimeout));
  }

  /// 监听网络连接变化 / Emits a fresh snapshot whenever connectivity changes.
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

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// 通过 HTTP 请求公共端点判定连通性 / Decides reachability via an HTTP probe.
  static Future<bool> _defaultReachabilityProbe() async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse('https://one.one.one.one/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
