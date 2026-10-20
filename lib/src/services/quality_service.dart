import '../models/dns_test_result.dart';
import '../models/network_quality_score.dart';
import '../models/ping_result.dart';
import '../models/speed_test_result.dart';
import '../utils/network_config.dart';
import 'connectivity_service.dart';
import 'dns_service.dart';
import 'ping_service.dart';
import 'quality_evaluator.dart';
import 'speed_test_service.dart';

/// 端到端网络质量评估服务 / End-to-end network quality assessment service.
///
/// 依次采集连接信息、延迟、DNS 与带宽指标后交给
/// [NetworkQualityEvaluator] 打分 / Collects connectivity, latency, DNS and
/// bandwidth metrics and feeds them to [NetworkQualityEvaluator].
class QualityService {
  /// 构造 [QualityService] / Creates a [QualityService].
  QualityService({
    ConnectivityService? connectivityService,
    PingService? pingService,
    DnsService? dnsService,
    SpeedTestService? speedTestService,
  }) : connectivity = connectivityService ?? ConnectivityService(),
       ping = pingService ?? const PingService(),
       dns = dnsService ?? const DnsService(),
       speedTest = speedTestService ?? const SpeedTestService();

  /// 连通性服务 / Connectivity service.
  final ConnectivityService connectivity;

  /// 延迟服务 / Latency service.
  final PingService ping;

  /// DNS 服务 / DNS service.
  final DnsService dns;

  /// 带宽服务 / Bandwidth service.
  final SpeedTestService speedTest;

  /// 评估当前网络质量 / Evaluates the current network quality.
  ///
  /// [includeSpeedTest] 会消耗较多流量，测试环境中建议关闭 /
  /// [includeSpeedTest] transfers a sizable amount of data; disable it in tests.
  Future<NetworkQualityScore> evaluateQuality({
    NetworkDiagnosticConfig config = const NetworkDiagnosticConfig(),
    bool includePing = true,
    bool includeDns = true,
    bool includeSpeedTest = true,
    bool includeUpload = true,
    String? pingHost,
    int? pingCount,
    Duration? pingTimeout,
    String? dnsDomain,
    List<String>? dnsServers,
    Duration? dnsTimeout,
    String? downloadUrl,
    String? uploadUrl,
  }) async {
    final connection = await connectivity.checkConnection();

    PingResult? pingResult;
    if (includePing) {
      pingResult = await ping.ping(
        host: pingHost ?? config.pingHost,
        count: pingCount ?? config.pingCount,
        timeout: pingTimeout ?? config.pingTimeout,
        interval: config.pingInterval,
        port: config.pingPort,
      );
    }

    double? dnsLatency;
    if (includeDns) {
      final results = await dns.testDns(
        domain: dnsDomain ?? config.dnsDomain,
        dnsServers: dnsServers ?? config.dnsServers,
        timeout: dnsTimeout ?? config.dnsTimeout,
      );
      dnsLatency = DnsTestResult.averageLatency(results);
    }

    SpeedTestResult? speed;
    if (includeSpeedTest) {
      try {
        speed = await speedTest.runSpeedTest(
          downloadUrl: downloadUrl ?? config.downloadUrl,
          uploadUrl: uploadUrl ?? config.uploadUrl,
          timeout: config.speedTestTimeout,
          maxDuration: config.speedTestMaxDuration,
          uploadPayloadBytes: config.uploadPayloadBytes,
          pingHost: pingHost ?? config.pingHost,
          pingCount: pingCount ?? config.pingCount,
          includeUpload: includeUpload,
          // 未单独跑延迟探测时，让测速顺带做一次：否则 `speed.ping` 恒为 0，
          // 下面的延迟 / 抖动回退永远取不到值（此前它是死代码）/ Run the latency
          // probe inside the speed test when no standalone ping was requested;
          // otherwise `speed.ping` stays 0 and the latency / jitter fallback
          // below can never fire (it used to be dead code).
          // 反之若已经单独跑过，就不再重复探测 / When a standalone ping did run,
          // the probe is deliberately not repeated.
          includePing: !includePing,
        );
      } catch (_) {
        speed = null;
      }
    }

    final latency = pingResult?.isSuccess == true
        ? pingResult!.averageTime
        : (speed != null && speed.ping > 0 ? speed.ping : null);
    final jitter = pingResult?.isSuccess == true
        ? pingResult!.jitter
        : (speed != null && speed.ping > 0 ? speed.jitter : null);
    final packetLoss = pingResult?.sent != null && pingResult!.sent > 0
        ? pingResult.packetLoss
        : null;

    return NetworkQualityEvaluator.evaluate(
      latency: latency,
      jitter: jitter,
      packetLoss: packetLoss,
      download: speed?.downloadSpeed,
      upload: includeUpload ? speed?.uploadSpeed : null,
      dns: dnsLatency,
      signalStrength: connection.signalStrength,
      targets: config.qualityTargets,
    );
  }
}
