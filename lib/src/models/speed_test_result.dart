/// 网速测试结果 / Result of a bandwidth (speed) test.
class SpeedTestResult {
  /// 构造 [SpeedTestResult] / Creates a [SpeedTestResult].
  const SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.timestamp,
    this.ping = 0,
    this.jitter = 0,
    this.packetLoss = 0,
    this.downloadedBytes = 0,
    this.uploadedBytes = 0,
    this.downloadDuration = Duration.zero,
    this.uploadDuration = Duration.zero,
    this.server,
  });

  /// 下载速率，单位 Mbps / Download throughput in Mbps.
  final double downloadSpeed;

  /// 上传速率，单位 Mbps / Upload throughput in Mbps.
  final double uploadSpeed;

  /// 平均延迟，单位毫秒 / Average latency in milliseconds.
  final double ping;

  /// 抖动，单位毫秒 / Jitter in milliseconds.
  final double jitter;

  /// 丢包率，百分比 / Packet loss ratio in percent.
  final double packetLoss;

  /// 累计下载字节数 / Bytes downloaded during the test.
  final int downloadedBytes;

  /// 累计上传字节数 / Bytes uploaded during the test.
  final int uploadedBytes;

  /// 下载阶段耗时 / Duration of the download phase.
  final Duration downloadDuration;

  /// 上传阶段耗时 / Duration of the upload phase.
  final Duration uploadDuration;

  /// 测试服务端标识（通常为下载 URL 的 host）/
  /// Server identifier, usually the host of the download URL.
  final String? server;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 总耗时 / Total elapsed duration.
  Duration get duration => downloadDuration + uploadDuration;

  /// 从下载字节数与耗时推算 Mbps / Computes Mbps from bytes and elapsed time.
  static double mbpsFromBytes(int bytes, Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return 0;
    return bytes * 8 / 1000000 / seconds;
  }

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'downloadSpeed': downloadSpeed,
    'uploadSpeed': uploadSpeed,
    'ping': ping,
    'jitter': jitter,
    'packetLoss': packetLoss,
    'downloadedBytes': downloadedBytes,
    'uploadedBytes': uploadedBytes,
    'downloadDurationMs': downloadDuration.inMilliseconds,
    'uploadDurationMs': uploadDuration.inMilliseconds,
    'server': server,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'SpeedTestResult(download: ${downloadSpeed.toStringAsFixed(2)}Mbps, '
      'upload: ${uploadSpeed.toStringAsFixed(2)}Mbps, '
      'ping: ${ping.toStringAsFixed(1)}ms)';
}
