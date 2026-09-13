import '../zero_network_kit_platform_interface.dart';
import 'models/dns_test_result.dart';
import 'models/network_connection_info.dart';
import 'models/network_diagnostic_report.dart';
import 'models/network_quality_score.dart';
import 'models/ping_result.dart';
import 'models/port_check_result.dart';
import 'models/network_capabilities.dart';
import 'models/speed_test_result.dart';
import 'services/connectivity_service.dart';
import 'services/dns_service.dart';
import 'services/ping_service.dart';
import 'services/port_service.dart';
import 'services/quality_evaluator.dart';
import 'services/quality_service.dart';
import 'services/speed_test_service.dart';
import 'utils/network_config.dart';

/// 网络诊断统一入口 / The single entry point for network diagnostics.
///
/// 全部方法均为静态方法且非阻塞；未显式配置时使用 [NetworkDiagnosticConfig] 的
/// 默认参数 / Every method is static and non-blocking; when nothing is
/// configured the defaults from [NetworkDiagnosticConfig] apply.
///
/// ```dart
/// final connection = await NetworkDiagnostic.checkConnection();
/// final ping = await NetworkDiagnostic.ping(host: '1.1.1.1');
/// final dns = await NetworkDiagnostic.testDns(domain: 'example.com');
/// final speed = await NetworkDiagnostic.runSpeedTest();
/// final quality = await NetworkDiagnostic.evaluateQuality();
/// ```
///
/// 测试时可替换任意服务实例 / Any service instance can be swapped in tests:
/// ```dart
/// NetworkDiagnostic.configure(ping: FakePingService());
/// ```
class NetworkDiagnostic {
  NetworkDiagnostic._();

  static NetworkDiagnosticConfig _config = const NetworkDiagnosticConfig();

  /// 连通性服务 / Connectivity service.
  static ConnectivityService connectivityService = ConnectivityService();

  /// 延迟测试服务 / Latency service.
  static PingService pingService = const PingService();

  /// DNS 服务 / DNS service.
  static DnsService dnsService = const DnsService();

  /// 端口检测服务 / Port service.
  static PortService portService = const PortService();

  /// 带宽测试服务 / Bandwidth service.
  static SpeedTestService speedTestService = const SpeedTestService();

  /// 质量评估服务 / Quality service.
  static QualityService qualityService = QualityService();

  /// 当前生效的默认配置 / The currently effective default configuration.
  static NetworkDiagnosticConfig get config => _config;

  /// 当前平台支持的能力集合 / Capabilities available on the current platform.
  ///
  /// UI 可据此隐藏不支持的卡片（例如桌面不展示 SSID / 信号强度）/
  /// Consumers can hide unsupported cards from the UI (e.g. SSID / signal
  /// strength on desktop).
  static NetworkCapabilities get capabilities => NetworkCapabilities.current();

  /// 覆盖默认配置与/或服务实例 / Overrides the default configuration and/or the
  /// service instances.
  ///
  /// 未传入的 [quality] 会基于最新的连通性 / 延迟 / DNS / 带宽服务自动重建 /
  /// When [quality] is omitted it is rebuilt on top of the latest connectivity,
  /// latency, DNS and bandwidth services.
  static void configure({
    NetworkDiagnosticConfig? config,
    ConnectivityService? connectivity,
    PingService? ping,
    DnsService? dns,
    PortService? ports,
    SpeedTestService? speedTest,
    QualityService? quality,
  }) {
    if (config != null) _config = config;
    if (connectivity != null) connectivityService = connectivity;
    if (ping != null) pingService = ping;
    if (dns != null) dnsService = dns;
    if (ports != null) portService = ports;
    if (speedTest != null) speedTestService = speedTest;
    qualityService =
        quality ??
        QualityService(
          connectivityService: connectivityService,
          pingService: pingService,
          dnsService: dnsService,
          speedTestService: speedTestService,
        );
  }

  /// 恢复出厂设置 / Restores the built-in defaults.
  static void reset() {
    _config = const NetworkDiagnosticConfig();
    connectivityService = ConnectivityService();
    pingService = const PingService();
    dnsService = const DnsService();
    portService = const PortService();
    speedTestService = const SpeedTestService();
    qualityService = QualityService();
  }

  /// 采集当前网络连接快照 / Captures the current connection snapshot.
  static Future<NetworkConnectionInfo> checkConnection({
    bool includeNativeDetails = true,
    bool probeReachability = false,
    Duration? probeTimeout,
  }) {
    return connectivityService.checkConnection(
      includeNativeDetails: includeNativeDetails,
      probeReachability: probeReachability,
      probeTimeout: probeTimeout ?? const Duration(seconds: 3),
    );
  }

  /// 监听网络连接变化 / Streams connection snapshots on every change.
  static Stream<NetworkConnectionInfo> get onConnectivityChanged =>
      connectivityService.onConnectivityChanged;

  /// 测量到目标主机的延迟 / Measures latency towards a target host.
  static Future<PingResult> ping({
    String? host,
    int? count,
    Duration? timeout,
    Duration? interval,
    int? port,
    PingMode mode = PingMode.tcp,
  }) {
    return pingService.ping(
      host: host ?? _config.pingHost,
      count: count ?? _config.pingCount,
      timeout: timeout ?? _config.pingTimeout,
      interval: interval ?? _config.pingInterval,
      port: port ?? _config.pingPort,
      mode: mode,
    );
  }

  /// 测试多台 DNS 服务器的解析表现 / Tests DNS resolution across servers.
  static Future<List<DnsTestResult>> resolve({
    String? domain,
    List<String>? dnsServers,
    Duration? timeout,
    bool concurrent = true,
    bool includeSystemResolver = false,
  }) {
    return dnsService.testDns(
      domain: domain ?? _config.dnsDomain,
      dnsServers: dnsServers ?? _config.dnsServers,
      timeout: timeout ?? _config.dnsTimeout,
      concurrent: concurrent,
      includeSystemResolver: includeSystemResolver,
    );
  }

  /// 检测单个端口是否可连接，返回完整结果对象 / Checks a single port and returns
  /// the full [PortCheckResult]. Use [isPortOpen] for a plain boolean.
  static Future<PortCheckResult> checkPort({
    required String host,
    required int port,
    Duration? timeout,
  }) {
    return portService.checkPort(
      host: host,
      port: port,
      timeout: timeout ?? _config.portCheckTimeout,
    );
  }

  /// 便捷布尔版：单个端口是否可连接 / Convenience boolean for a single port.
  static Future<bool> isPortOpen({
    required String host,
    required int port,
    Duration? timeout,
  }) async {
    final result = await checkPort(host: host, port: port, timeout: timeout);
    return result.isOpen;
  }

  /// 批量扫描端口 / Scans a list of ports concurrently.
  static Future<List<PortCheckResult>> scanPorts({
    required String host,
    List<int>? ports,
    Duration? timeout,
    int concurrency = 12,
  }) {
    return portService.scanPorts(
      host: host,
      ports: ports ?? _config.probePorts,
      timeout: timeout ?? _config.portCheckTimeout,
      concurrency: concurrency,
    );
  }

  /// 执行下载/上传测速 / Runs a download and upload throughput test.
  static Future<SpeedTestResult> runSpeedTest({
    String? downloadUrl,
    String? uploadUrl,
    Duration? timeout,
    Duration? maxDuration,
    int? uploadPayloadBytes,
    String? pingHost,
    int? pingCount,
    bool includeUpload = true,
    bool includePing = true,
    void Function(SpeedTestProgress progress)? onProgress,
  }) {
    return speedTestService.runSpeedTest(
      downloadUrl: downloadUrl ?? _config.downloadUrl,
      uploadUrl: uploadUrl ?? _config.uploadUrl,
      timeout: timeout ?? _config.speedTestTimeout,
      maxDuration: maxDuration ?? _config.speedTestMaxDuration,
      uploadPayloadBytes: uploadPayloadBytes ?? _config.uploadPayloadBytes,
      pingHost: pingHost ?? _config.pingHost,
      pingCount: pingCount ?? _config.pingCount,
      includeUpload: includeUpload,
      includePing: includePing,
      onProgress: onProgress,
    );
  }

  /// 评估当前网络质量 / Evaluates the current network quality.
  static Future<NetworkQualityScore> evaluateQuality({
    bool includePing = true,
    bool includeDns = true,
    bool includeSpeedTest = true,
    bool includeUpload = true,
    String? pingHost,
    int? pingCount,
    String? dnsDomain,
    List<String>? dnsServers,
    String? downloadUrl,
    String? uploadUrl,
  }) {
    return qualityService.evaluateQuality(
      config: _config,
      includePing: includePing,
      includeDns: includeDns,
      includeSpeedTest: includeSpeedTest,
      includeUpload: includeUpload,
      pingHost: pingHost,
      pingCount: pingCount,
      dnsDomain: dnsDomain,
      dnsServers: dnsServers,
      downloadUrl: downloadUrl,
      uploadUrl: uploadUrl,
    );
  }

  /// 运行一次完整诊断并汇总为报告 / Runs a full diagnostic and aggregates a report.
  ///
  /// 任何子项失败都不会中断整体流程 / A failing sub-test never aborts the whole
  /// run; its own result field simply stays empty.
  static Future<NetworkDiagnosticReport> diagnose({
    bool includePing = true,
    bool includeDns = true,
    bool includePorts = false,
    bool includeSpeedTest = true,
    bool includeUpload = true,
    String? host,
    String? dnsDomain,
    List<String>? dnsServers,
    List<int>? ports,
  }) async {
    final connection = await checkConnection();
    final targetHost = host ?? _config.pingHost;

    PingResult? pingResult;
    if (includePing) {
      pingResult = await ping(host: targetHost);
    }

    var dnsResults = const <DnsTestResult>[];
    if (includeDns) {
      dnsResults = await resolve(domain: dnsDomain, dnsServers: dnsServers);
    }

    var portResults = const <PortCheckResult>[];
    if (includePorts) {
      portResults = await scanPorts(host: targetHost, ports: ports);
    }

    SpeedTestResult? speed;
    if (includeSpeedTest) {
      try {
        speed = await runSpeedTest(
          pingHost: targetHost,
          includeUpload: includeUpload,
        );
      } catch (_) {
        speed = null;
      }
    }

    final successfulDns = dnsResults
        .where((result) => result.isSuccess)
        .toList(growable: false);
    final dnsLatency = successfulDns.isEmpty
        ? null
        : successfulDns.fold<double>(
                0,
                (previous, result) => previous + result.responseTimeMs,
              ) /
              successfulDns.length;

    final quality = NetworkQualityEvaluator.evaluate(
      latency: pingResult?.isSuccess == true ? pingResult?.averageTime : null,
      jitter: pingResult?.isSuccess == true ? pingResult?.jitter : null,
      packetLoss: pingResult != null && pingResult.sent > 0
          ? pingResult.packetLoss
          : null,
      download: speed?.downloadSpeed,
      upload: includeUpload ? speed?.uploadSpeed : null,
      dns: dnsLatency,
      signalStrength: connection.signalStrength,
      targets: _config.qualityTargets,
    );

    return NetworkDiagnosticReport(
      connection: connection,
      ping: pingResult,
      dnsResults: dnsResults,
      portResults: portResults,
      speedTest: speed,
      quality: quality,
      timestamp: DateTime.now(),
    );
  }

  /// 读取原生平台版本 / Reads the native platform version.
  static Future<String?> getPlatformVersion() =>
      ZeroNetworkKitPlatform.instance.getPlatformVersion();

  /// 读取原生网络详情（SSID、网关、MAC 等）/ Reads native network details such as
  /// SSID, gateway and MAC address.
  static Future<Map<String, Object?>?> getNativeNetworkDetails() =>
      ZeroNetworkKitPlatform.instance.getNetworkDetails();
}
