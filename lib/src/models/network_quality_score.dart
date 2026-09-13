/// 网络质量等级 / Overall network quality level.
enum NetworkQualityLevel {
  /// 未评估 / Not evaluated.
  unknown,

  /// 极佳 / Excellent.
  excellent,

  /// 良好 / Good.
  good,

  /// 一般 / Fair.
  fair,

  /// 较差 / Poor.
  poor,

  /// 极差 / Bad.
  bad;

  /// 从 0–100 分值映射等级 / Maps a 0–100 score to a level.
  static NetworkQualityLevel fromScore(double score) {
    if (score >= 90) return NetworkQualityLevel.excellent;
    if (score >= 75) return NetworkQualityLevel.good;
    if (score >= 60) return NetworkQualityLevel.fair;
    if (score >= 40) return NetworkQualityLevel.poor;
    return NetworkQualityLevel.bad;
  }

  /// 人类可读名称 / Human readable label.
  String get label => switch (this) {
    NetworkQualityLevel.unknown => 'Unknown',
    NetworkQualityLevel.excellent => 'Excellent',
    NetworkQualityLevel.good => 'Good',
    NetworkQualityLevel.fair => 'Fair',
    NetworkQualityLevel.poor => 'Poor',
    NetworkQualityLevel.bad => 'Bad',
  };
}

/// 网络质量评分 / Composite network quality score.
class NetworkQualityScore {
  /// 构造 [NetworkQualityScore] / Creates a [NetworkQualityScore].
  const NetworkQualityScore({
    required this.score,
    required this.level,
    required this.timestamp,
    this.metrics = const <String, double>{},
    this.suggestions = const <String>[],
  });

  /// 综合得分，0–100 / Composite score in the 0–100 range.
  final double score;

  /// 综合得分对应等级 / Level derived from [score].
  final NetworkQualityLevel level;

  /// 各项原始指标（`latency`、`jitter`、`packetLoss`、`download`、`upload`、
  /// `dns`、`signalStrength` 等）/ Raw metric values such as `latency`,
  /// `jitter`, `packetLoss`, `download`, `upload`, `dns` and `signalStrength`.
  final Map<String, double> metrics;

  /// 优化建议 / Actionable suggestions derived from weak metrics.
  final List<String> suggestions;

  /// 评估时间 / Evaluation timestamp.
  final DateTime timestamp;

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'score': score,
    'level': level.name,
    'metrics': metrics,
    'suggestions': suggestions,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'NetworkQualityScore(score: ${score.toStringAsFixed(1)}, '
      'level: ${level.name})';
}
