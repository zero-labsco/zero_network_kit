/// 端口连通性检测结果 / Result of a TCP port reachability check.
class PortCheckResult {
  /// 构造 [PortCheckResult] / Creates a [PortCheckResult].
  const PortCheckResult({
    required this.host,
    required this.port,
    required this.isOpen,
    required this.responseTime,
    required this.timestamp,
    this.errorMessage,
  });

  /// 目标主机 / Target host.
  final String host;

  /// 目标端口 / Target port.
  final int port;

  /// 端口是否开放 / Whether the port accepted the TCP connection.
  final bool isOpen;

  /// 连接耗时 / Time taken to establish (or fail) the connection.
  final Duration responseTime;

  /// 失败原因 / Failure reason when [isOpen] is `false`.
  final String? errorMessage;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 连接耗时，单位毫秒 / Elapsed time in milliseconds.
  double get responseTimeMs => responseTime.inMicroseconds / 1000;

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'host': host,
    'port': port,
    'isOpen': isOpen,
    'responseTimeMs': responseTimeMs,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'PortCheckResult($host:$port, open: $isOpen, '
      'time: ${responseTimeMs.toStringAsFixed(1)}ms)';
}
