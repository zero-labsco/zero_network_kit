import '../zero_network_kit_platform_interface.dart';
import 'models/benchmark_result.dart';
import 'network_diagnostic.dart';
import 'services/benchmark_service.dart';

/// 网络诊断微基准测试入口 / Micro-benchmark entry point for the diagnostics API.
///
/// 用于回答“这套诊断 API 本身有多快” / Answers the question "how fast is the
/// diagnostics API itself".
///
/// ```dart
/// final suite = await NetworkBenchmark.runAll(iterations: 20);
/// print(suite['ping']!.averageDuration);
/// ```
class NetworkBenchmark {
  NetworkBenchmark._();

  /// 底层执行器 / The underlying runner.
  static const BenchmarkService service = BenchmarkService();

  /// 顺序运行全部基准测试 / Runs every benchmark sequentially.
  static Future<BenchmarkSuiteResult> runAll({
    int iterations = 20,
    int warmupIterations = 3,
    String? host,
    String? dnsDomain,
    List<String>? dnsServers,
    int? port,
  }) {
    final config = NetworkDiagnostic.config;
    final targetHost = host ?? config.pingHost;
    final targetPort = port ?? config.pingPort;

    return service.runSuite(
      suiteName: 'zero_network_kit',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'connection': (_) => NetworkDiagnostic.checkConnection(
          includeNativeDetails: false,
        ).then((_) {}),
        'ping': (_) => NetworkDiagnostic.ping(
          host: targetHost,
          count: 1,
          interval: Duration.zero,
          port: targetPort,
        ).then((_) {}),
        'dns': (_) => NetworkDiagnostic.resolve(
          domain: dnsDomain ?? config.dnsDomain,
          dnsServers: dnsServers ?? config.dnsServers,
          concurrent: false,
        ).then((_) {}),
        'portCheck': (_) => NetworkDiagnostic.checkPort(
          host: targetHost,
          port: targetPort,
        ).then((_) {}),
      },
    );
  }

  /// 基准测试连接检查 / Benchmarks the connection check.
  static Future<BenchmarkSuiteResult> benchmarkConnection({
    int iterations = 20,
    int warmupIterations = 3,
  }) {
    return service.runSuite(
      suiteName: 'connection',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'connection': (_) => NetworkDiagnostic.checkConnection(
          includeNativeDetails: false,
        ).then((_) {}),
      },
    );
  }

  /// 基准测试延迟探测 / Benchmarks the latency probe.
  static Future<BenchmarkSuiteResult> benchmarkPing({
    int iterations = 20,
    int warmupIterations = 3,
    String? host,
    int? port,
  }) {
    final config = NetworkDiagnostic.config;
    return service.runSuite(
      suiteName: 'ping',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'ping': (_) => NetworkDiagnostic.ping(
          host: host ?? config.pingHost,
          count: 1,
          interval: Duration.zero,
          port: port ?? config.pingPort,
        ).then((_) {}),
      },
    );
  }

  /// 基准测试 DNS 解析 / Benchmarks DNS resolution.
  static Future<BenchmarkSuiteResult> benchmarkDns({
    int iterations = 20,
    int warmupIterations = 3,
    String? domain,
    List<String>? dnsServers,
  }) {
    final config = NetworkDiagnostic.config;
    return service.runSuite(
      suiteName: 'dns',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'dns': (_) => NetworkDiagnostic.resolve(
          domain: domain ?? config.dnsDomain,
          dnsServers: dnsServers ?? config.dnsServers,
          concurrent: false,
        ).then((_) {}),
      },
    );
  }

  /// 基准测试端口检测 / Benchmarks the port check.
  static Future<BenchmarkSuiteResult> benchmarkPortCheck({
    int iterations = 20,
    int warmupIterations = 3,
    String? host,
    int? port,
  }) {
    final config = NetworkDiagnostic.config;
    return service.runSuite(
      suiteName: 'portCheck',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'portCheck': (_) => NetworkDiagnostic.checkPort(
          host: host ?? config.pingHost,
          port: port ?? config.pingPort,
        ).then((_) {}),
      },
    );
  }

  /// 基准测试原生通道往返 / Benchmarks the platform-channel round trip.
  static Future<BenchmarkSuiteResult> benchmarkPlatformChannel({
    int iterations = 20,
    int warmupIterations = 3,
  }) {
    return service.runSuite(
      suiteName: 'platformChannel',
      iterations: iterations,
      warmupIterations: warmupIterations,
      tasks: <String, Future<void> Function(int iteration)>{
        'platformChannel': (_) =>
            ZeroNetworkKitPlatform.instance.getPlatformVersion().then((_) {}),
      },
    );
  }
}
