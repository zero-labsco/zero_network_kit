/// Flutter 网络诊断插件 / A Flutter plugin for network diagnostics.
///
/// 提供连通性检测、延迟探测、DNS 解析、端口检测、带宽测速、质量评分与微基准
/// 测试能力，全部通过包根 [ZeroNetworkKit] / `NetworkDiagnostic` /
/// `NetworkBenchmark` 暴露，消费者不应直接引用 `lib/src/` /
/// Provides connectivity checks, latency probes, DNS resolution, port checks,
/// bandwidth measurement, quality scoring and micro-benchmarks. Everything is
/// exposed through the package root; consumers must never import `lib/src/`
/// directly.
library;

export 'src/models/benchmark_result.dart';
export 'src/models/dns_test_result.dart';
export 'src/models/network_connection_info.dart';
export 'src/models/network_capabilities.dart';
export 'src/models/network_diagnostic_report.dart';
export 'src/models/network_quality_score.dart';
export 'src/models/network_type.dart';
export 'src/models/ping_result.dart';
export 'src/models/port_check_result.dart';
export 'src/models/speed_test_result.dart';
export 'src/network_benchmark.dart';
export 'src/network_diagnostic.dart';
export 'src/utils/network_config.dart';
export 'zero_network_kit_platform_interface.dart';

import 'package:http/http.dart' as http;

import 'src/network_diagnostic.dart';
import 'src/services/speed_test_service.dart';
import 'src/utils/network_config.dart';
import 'zero_network_kit_platform_interface.dart';

/// ZeroNetworkKit 插件入口类 / ZeroNetworkKit plugin entry class.
///
/// 只需要在 `main()` 里调用一次 [init] 即可全局定制诊断参数；不调用也能直接
/// 使用 [NetworkDiagnostic] 与 [NetworkBenchmark]（走内置默认值）/
/// Calling [init] once in `main()` applies global configuration; the
/// diagnostics and benchmark APIs work with built-in defaults even without it.
///
/// ```dart
/// void main() {
///   ZeroNetworkKit.init(
///     config: const NetworkDiagnosticConfig(pingHost: '8.8.8.8'),
///   );
///   runApp(const MyApp());
/// }
/// ```
class ZeroNetworkKit {
  ZeroNetworkKit._();

  static NetworkDiagnosticConfig _config = const NetworkDiagnosticConfig();
  static http.Client? _ownedClient;
  static bool _initialized = false;

  /// 当前生效的默认配置 / The currently effective default configuration.
  static NetworkDiagnosticConfig get config => _config;

  /// 是否已调用过 [init] / Whether [init] has been called.
  static bool get isInitialized => _initialized;

  /// 初始化插件并应用全局配置 / Initialises the plugin and applies global
  /// configuration.
  ///
  /// [httpClient] 为 `null` 时由插件自行创建并持有（[dispose] 时关闭）；外部传入
  /// 的客户端不会被关闭，由调用方负责 / When [httpClient] is `null` the plugin
  /// creates and owns a client and closes it in [dispose]; an externally
  /// supplied client is never closed by the plugin.
  ///
  /// 重复调用是安全的，后一次会覆盖前一次的配置 / Calling it repeatedly is
  /// safe; the latest call wins.
  static void init({NetworkDiagnosticConfig? config, http.Client? httpClient}) {
    if (config != null) _config = config;

    final client = httpClient ?? http.Client();
    if (httpClient == null) {
      _ownedClient?.close();
      _ownedClient = client;
    }

    NetworkDiagnostic.configure(
      config: _config,
      speedTest: SpeedTestService(client: client),
    );
    _initialized = true;
  }

  /// 释放插件持有的资源并恢复默认配置 /
  /// Releases the resources owned by the plugin and restores the defaults.
  ///
  /// 调用后仍可继续使用各项 API，也可以再次调用 [init] /
  /// The APIs remain usable afterwards, and [init] may be called again.
  static Future<void> dispose() async {
    _ownedClient?.close();
    _ownedClient = null;
    NetworkDiagnostic.reset();
    _config = const NetworkDiagnosticConfig();
    _initialized = false;
  }

  /// 读取原生平台版本，例如 `Android 14` / `iOS 18.0` /
  /// Reads the native platform version, e.g. `Android 14` / `iOS 18.0`.
  static Future<String?> getPlatformVersion() =>
      ZeroNetworkKitPlatform.instance.getPlatformVersion();

  /// 读取原生网络详情 / Reads the native network details.
  static Future<Map<String, Object?>?> getNativeNetworkDetails() =>
      ZeroNetworkKitPlatform.instance.getNetworkDetails();
}
