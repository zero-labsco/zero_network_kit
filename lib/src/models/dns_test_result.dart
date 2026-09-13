/// 单台 DNS 服务器的解析结果 / Resolution result for a single DNS server.
class DnsTestResult {
  /// 构造 [DnsTestResult] / Creates a [DnsTestResult].
  const DnsTestResult({
    required this.server,
    required this.domain,
    required this.isSuccess,
    required this.responseTime,
    required this.timestamp,
    this.resolvedIps = const <String>[],
    this.errorMessage,
  });

  /// DNS 服务器地址（`system` 代表系统解析器）/
  /// DNS server address (`system` means the platform resolver).
  final String server;

  /// 被解析的域名 / Resolved domain.
  final String domain;

  /// 是否解析成功 / Whether the lookup succeeded.
  final bool isSuccess;

  /// 解析耗时 / Elapsed resolution time.
  final Duration responseTime;

  /// 解析得到的地址列表 / Resolved addresses.
  final List<String> resolvedIps;

  /// 失败原因 / Failure reason when [isSuccess] is `false`.
  final String? errorMessage;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 解析耗时，单位毫秒 / Resolution time in milliseconds.
  double get responseTimeMs => responseTime.inMicroseconds / 1000;

  /// 首个解析地址，未解析成功时为 `null` /
  /// First resolved address, or `null` on failure.
  String? get primaryAddress => resolvedIps.isEmpty ? null : resolvedIps.first;

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'server': server,
    'domain': domain,
    'isSuccess': isSuccess,
    'responseTimeMs': responseTimeMs,
    'resolvedIps': resolvedIps,
    'errorMessage': errorMessage,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'DnsTestResult(server: $server, domain: $domain, '
      'success: $isSuccess, time: ${responseTimeMs.toStringAsFixed(1)}ms, '
      'ips: ${resolvedIps.join(', ')})';
}
