import 'dns_test_result.dart';
import 'network_connection_info.dart';
import 'network_quality_score.dart';
import 'ping_result.dart';
import 'port_check_result.dart';
import 'speed_test_result.dart';

/// 一次完整网络诊断的汇总报告 / Aggregated report of a full diagnostic run.
class NetworkDiagnosticReport {
  /// 构造 [NetworkDiagnosticReport] / Creates a [NetworkDiagnosticReport].
  const NetworkDiagnosticReport({
    required this.connection,
    required this.quality,
    required this.timestamp,
    this.ping,
    this.dnsResults = const <DnsTestResult>[],
    this.portResults = const <PortCheckResult>[],
    this.speedTest,
  });

  /// 连接信息 / Connection snapshot.
  final NetworkConnectionInfo connection;

  /// Ping 结果，未执行时为 `null` / Ping result, `null` when skipped.
  final PingResult? ping;

  /// DNS 结果列表 / Per-server DNS results.
  final List<DnsTestResult> dnsResults;

  /// 端口检测结果列表 / Port check results.
  final List<PortCheckResult> portResults;

  /// 网速测试结果，未执行时为 `null` / Speed test result, `null` when skipped.
  final SpeedTestResult? speedTest;

  /// 质量评分 / Composite quality score.
  final NetworkQualityScore quality;

  /// 生成时间 / Generation timestamp.
  final DateTime timestamp;

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'connection': connection.toMap(),
    'ping': ping?.toMap(),
    'dnsResults': dnsResults.map((result) => result.toMap()).toList(),
    'portResults': portResults.map((result) => result.toMap()).toList(),
    'speedTest': speedTest?.toMap(),
    'quality': quality.toMap(),
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'NetworkDiagnosticReport(type: ${connection.type.id}, '
      'connected: ${connection.isConnected}, '
      'score: ${quality.score.toStringAsFixed(1)})';
}
