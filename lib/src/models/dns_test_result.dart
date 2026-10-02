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

  /// 一组结果中成功项的平均解析耗时（毫秒）；全部失败时为 `null` /
  /// Mean resolution time (ms) across the successful results; `null` when every
  /// one of them failed.
  ///
  /// 失败的查询不计入平均值：它的耗时等于超时上限，混进来会把整批结果拉到不可信
  /// 的水平 / Failures are excluded: their duration is the full timeout, and
  /// averaging them in would make the whole batch meaningless.
  static double? averageLatency(Iterable<DnsTestResult> results) {
    final successful = results
        .where((result) => result.isSuccess)
        .toList(growable: false);
    if (successful.isEmpty) return null;
    final total = successful.fold<double>(
      0,
      (previous, result) => previous + result.responseTimeMs,
    );
    return total / successful.length;
  }

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
