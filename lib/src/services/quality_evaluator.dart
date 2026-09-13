import 'dart:math' as math;

import '../models/network_quality_score.dart';
import '../utils/network_config.dart';

/// 网络质量评分器 / Composite network quality scorer.
///
/// 纯函数实现，不产生任何 IO，方便单元测试与自定义权重 /
/// Pure functions with no IO, which keeps it unit-testable and reusable.
class NetworkQualityEvaluator {
  const NetworkQualityEvaluator._();

  /// 各指标权重（分母按可用指标归一化）/
  /// Per-metric weights; the denominator is normalised over available metrics.
  static const Map<String, double> _weights = <String, double>{
    'latency': 0.25,
    'jitter': 0.10,
    'packetLoss': 0.15,
    'download': 0.25,
    'upload': 0.15,
    'dns': 0.10,
    'signalStrength': 0.10,
  };

  /// 计算综合得分 / Computes the composite score.
  ///
  /// 所有指标均可选，缺失的指标不参与加权 / Every metric is optional; missing
  /// metrics are excluded from the weighted average.
  static NetworkQualityScore evaluate({
    double? latency,
    double? jitter,
    double? packetLoss,
    double? download,
    double? upload,
    double? dns,
    int? signalStrength,
    QualityTargets targets = const QualityTargets(),
    DateTime? timestamp,
  }) {
    final targetsSet = targets;
    final subScores = <String, double>{};
    final raw = <String, double>{};

    if (latency != null) {
      subScores['latency'] = _lowerIsBetter(
        latency,
        excellent: targetsSet.excellentLatency,
        acceptable: targetsSet.acceptableLatency,
      );
      raw['latency'] = latency;
    }
    if (jitter != null) {
      subScores['jitter'] = _lowerIsBetter(
        jitter,
        excellent: targetsSet.excellentJitter,
        acceptable: targetsSet.acceptableJitter,
      );
      raw['jitter'] = jitter;
    }
    if (packetLoss != null) {
      subScores['packetLoss'] = _lowerIsBetter(
        packetLoss,
        excellent: 0,
        acceptable: targetsSet.acceptablePacketLoss,
      );
      raw['packetLoss'] = packetLoss;
    }
    if (download != null) {
      subScores['download'] = _higherIsBetter(
        download,
        acceptable: targetsSet.acceptableDownload,
        excellent: targetsSet.excellentDownload,
      );
      raw['download'] = download;
    }
    if (upload != null) {
      subScores['upload'] = _higherIsBetter(
        upload,
        acceptable: targetsSet.acceptableUpload,
        excellent: targetsSet.excellentUpload,
      );
      raw['upload'] = upload;
    }
    if (dns != null) {
      subScores['dns'] = _lowerIsBetter(
        dns,
        excellent: targetsSet.excellentDns,
        acceptable: targetsSet.acceptableDns,
      );
      raw['dns'] = dns;
    }
    if (signalStrength != null) {
      subScores['signalStrength'] = _higherIsBetter(
        signalStrength.toDouble(),
        acceptable: -88,
        excellent: -50,
      );
      raw['signalStrength'] = signalStrength.toDouble();
    }

    if (subScores.isEmpty) {
      return NetworkQualityScore(
        score: 0,
        level: NetworkQualityLevel.unknown,
        metrics: const <String, double>{},
        suggestions: const <String>[
          'Run a diagnostic first to collect metrics',
        ],
        timestamp: timestamp ?? DateTime.now(),
      );
    }

    var weightedSum = 0.0;
    var weightSum = 0.0;
    subScores.forEach((metric, value) {
      final weight = _weights[metric] ?? 0;
      weightedSum += value * weight;
      weightSum += weight;
    });

    final score = weightSum == 0 ? 0.0 : weightedSum / weightSum;

    final metrics = <String, double>{...raw};
    subScores.forEach((metric, value) {
      metrics['subScore.$metric'] = value;
    });

    return NetworkQualityScore(
      score: double.parse(score.toStringAsFixed(2)),
      level: NetworkQualityLevel.fromScore(score),
      metrics: metrics,
      suggestions: _suggestions(subScores, targetsSet),
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// 越小越好的指标 → 分值 / Maps a "lower is better" metric to a score.
  ///
  /// `excellent` 及以下得 100 分，`acceptable` 得 40 分，之后线性下降到 0 /
  /// Values at or below `excellent` score 100; `acceptable` scores 40; beyond
  /// that the score decays linearly to 0.
  static double _lowerIsBetter(
    double value, {
    required double excellent,
    required double acceptable,
  }) {
    if (value <= excellent) return 100;
    final span = acceptable - excellent;
    if (span <= 0) return value <= acceptable ? 40 : 0;
    if (value <= acceptable) {
      return 100 - 60 * (value - excellent) / span;
    }
    return math.max(0, 40 * (1 - (value - acceptable) / span));
  }

  /// 越大越好的指标 → 分值 / Maps a "higher is better" metric to a score.
  static double _higherIsBetter(
    double value, {
    required double acceptable,
    required double excellent,
  }) {
    if (value >= excellent) return 100;
    if (value <= acceptable) {
      if (acceptable <= 0) return 0;
      return math.max(0, 40 * value / acceptable);
    }
    final span = excellent - acceptable;
    if (span <= 0) return 100;
    return 40 + 60 * (value - acceptable) / span;
  }

  static List<String> _suggestions(
    Map<String, double> subScores,
    QualityTargets targets,
  ) {
    final suggestions = <String>[];
    final latency = subScores['latency'];
    final jitter = subScores['jitter'];
    final loss = subScores['packetLoss'];
    final download = subScores['download'];
    final upload = subScores['upload'];
    final dns = subScores['dns'];
    final signal = subScores['signalStrength'];

    if (latency != null && latency < 60) {
      suggestions.add(
        'High latency: switch to a closer server or a wired connection.',
      );
    }
    if (jitter != null && jitter < 60) {
      suggestions.add('Unstable latency: avoid congested Wi-Fi channels.');
    }
    if (loss != null && loss < 90) {
      suggestions.add(
        'Packet loss detected: check cables, router load and Wi-Fi signal.',
      );
    }
    if (download != null && download < 60) {
      suggestions.add('Low download throughput: pause background downloads.');
    }
    if (upload != null && upload < 60) {
      suggestions.add('Low upload throughput: limit concurrent uploads.');
    }
    if (dns != null && dns < 60) {
      suggestions.add(
        'Slow DNS resolution: try 1.1.1.1 or 8.8.8.8 as your resolver.',
      );
    }
    if (signal != null && signal < 60) {
      suggestions.add('Weak Wi-Fi signal: move closer to the access point.');
    }
    if (suggestions.isEmpty) {
      suggestions.add('Network quality is healthy; no action needed.');
    }
    return suggestions;
  }
}
