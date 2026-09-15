import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' show Event, EventStreamProvider, window;

import '../../zero_network_kit_platform_interface.dart';
import '../models/network_connection_info.dart';
import '../models/network_type.dart';

/// 连接类型数据源抽象 / Abstraction over the platform connectivity source.
///
/// Web 端默认由 `package:web`（浏览器 `navigator.onLine`）实现，单元测试可注入假实现 /
/// On the web it is backed by `package:web` (the browser's `navigator.onLine`) by
/// default; unit tests can inject fakes.
abstract class ConnectivityAdapter {
  /// 读取当前连接类型（如 `['wifi']`）/ Reads the current transports, e.g.
  /// `['wifi']`.
  Future<List<String>> checkConnectivity();

  /// 监听连接类型变化 / Emits whenever the transports change.
  Stream<List<String>> get onConnectivityChanged;
}

/// 基于浏览器 `navigator.onLine` 的 Web 连通性适配器 /
/// Web connectivity adapter backed by the browser's `navigator.onLine`.
///
/// 浏览器无法区分 Wi-Fi / 蜂窝等具体传输类型，仅能判断「在线 / 离线」，因此在线时
/// 返回 `['wifi']`、离线时返回 `['none']` /
/// Browsers cannot tell Wi-Fi from cellular; they only report online / offline, so
/// the adapter emits `['wifi']` when online and `['none']` when offline.
///
/// 直接基于 `package:web` 实现，避免把 `connectivity_plus` 引入 Web 依赖图，从而保证
/// 包对 WebAssembly（WASM）编译友好 / Implemented directly on top of `package:web`
/// instead of `connectivity_plus` so the package stays WASM-compatible (the plugin's
/// Linux-only `nm` dependency would otherwise leak into the web import graph).
class WebConnectivityAdapter implements ConnectivityAdapter {
  /// 构造 [WebConnectivityAdapter] / Creates a [WebConnectivityAdapter].
  WebConnectivityAdapter();

  @override
  Future<List<String>> checkConnectivity() async {
    return window.navigator.onLine ? const ['wifi'] : const ['none'];
  }

  @override
  Stream<List<String>> get onConnectivityChanged {
    final controller = StreamController<List<String>>.broadcast();
    EventStreamProvider<Event>(
      'online',
    ).forTarget(window).listen((_) => controller.add(const ['wifi']));
    EventStreamProvider<Event>(
      'offline',
    ).forTarget(window).listen((_) => controller.add(const ['none']));
    return controller.stream;
  }
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
    : _adapter = adapter ?? WebConnectivityAdapter();

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
