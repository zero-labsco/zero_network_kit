import 'dart:math' as math;

/// Ping 探测方式 / How the ping probes are performed.
enum PingMode {
  /// TCP 握手往返（跨平台，默认）/ TCP handshake round trip (cross platform,
  /// default). ICMP echo requests require raw sockets and are unavailable to
  /// sandboxed applications, so a TCP connect to a reachable port is the
  /// portable equivalent.
  tcp,

  /// 系统 ICMP `ping` 命令（仅桌面端）/ The system ICMP `ping` command
  /// (desktop only).
  icmp,
}

/// Ping 测试结果 / Result of a ping test.
class PingResult {
  /// 构造 [PingResult] / Creates a [PingResult].
  const PingResult({
    required this.host,
    required this.sent,
    required this.received,
    required this.times,
    required this.timestamp,
    this.port,
    this.mode = PingMode.tcp,
  });

  /// 目标主机 / Target host.
  final String host;

  /// 目标端口（TCP 模式）/ Target port (TCP mode only).
  final int? port;

  /// 探测方式 / Probe mode used.
  final PingMode mode;

  /// 发出的探测包数量 / Number of probes sent.
  final int sent;

  /// 成功收到的响应数量 / Number of successful responses.
  final int received;

  /// 每次成功探测的往返耗时，单位毫秒 / Round trip time of every successful
  /// probe, in milliseconds.
  final List<double> times;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 丢包数量 / Number of lost probes.
  int get lost => math.max(0, sent - received);

  /// 丢包率，百分比 / Packet loss ratio, in percent.
  double get packetLoss => sent == 0 ? 0 : lost * 100 / sent;

  /// 最小往返耗时（毫秒）/ Minimum round trip time in milliseconds.
  double get minTime => times.isEmpty ? 0 : times.reduce(math.min);

  /// 最大往返耗时（毫秒）/ Maximum round trip time in milliseconds.
  double get maxTime => times.isEmpty ? 0 : times.reduce(math.max);

  /// 平均往返耗时（毫秒）/ Average round trip time in milliseconds.
  double get averageTime =>
      times.isEmpty ? 0 : times.reduce((a, b) => a + b) / times.length;

  /// 抖动，相邻探测往返耗时差值的平均绝对值，单位毫秒 /
  /// Jitter: mean absolute difference between consecutive round trip times,
  /// in milliseconds.
  double get jitter {
    if (times.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < times.length; i++) {
      total += (times[i] - times[i - 1]).abs();
    }
    return total / (times.length - 1);
  }

  /// 是否至少有一次成功响应 / Whether at least one probe succeeded.
  bool get isSuccess => received > 0;

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'host': host,
    'port': port,
    'mode': mode.name,
    'sent': sent,
    'received': received,
    'lost': lost,
    'packetLoss': packetLoss,
    'minTime': minTime,
    'maxTime': maxTime,
    'averageTime': averageTime,
    'jitter': jitter,
    'times': times,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'PingResult(host: $host, sent: $sent, received: $received, '
      'loss: ${packetLoss.toStringAsFixed(1)}%, '
      'avg: ${averageTime.toStringAsFixed(1)}ms)';
}
