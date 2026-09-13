import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/zero_network_kit.dart';
import 'package:zero_network_kit/advanced.dart';

void main() {
  group('NetworkQualityLevel.fromScore', () {
    test('maps score bands to levels', () {
      expect(NetworkQualityLevel.fromScore(100), NetworkQualityLevel.excellent);
      expect(NetworkQualityLevel.fromScore(90), NetworkQualityLevel.excellent);
      expect(NetworkQualityLevel.fromScore(89.99), NetworkQualityLevel.good);
      expect(NetworkQualityLevel.fromScore(75), NetworkQualityLevel.good);
      expect(NetworkQualityLevel.fromScore(60), NetworkQualityLevel.fair);
      expect(NetworkQualityLevel.fromScore(40), NetworkQualityLevel.poor);
      expect(NetworkQualityLevel.fromScore(39.99), NetworkQualityLevel.bad);
    });
  });

  group('NetworkQualityEvaluator.evaluate', () {
    test('returns unknown when no metric is available', () {
      final score = NetworkQualityEvaluator.evaluate();

      expect(score.level, NetworkQualityLevel.unknown);
      expect(score.score, 0);
      expect(score.suggestions, isNotEmpty);
    });

    test('rewards an ideal network', () {
      final score = NetworkQualityEvaluator.evaluate(
        latency: 10,
        jitter: 1,
        packetLoss: 0,
        download: 200,
        upload: 100,
        dns: 5,
        signalStrength: -45,
      );

      expect(score.score, 100);
      expect(score.level, NetworkQualityLevel.excellent);
      expect(score.suggestions.single, contains('healthy'));
    });

    test('penalises a degraded network', () {
      final score = NetworkQualityEvaluator.evaluate(
        latency: 400,
        jitter: 120,
        packetLoss: 30,
        download: 0.2,
        upload: 0.1,
        dns: 900,
      );

      expect(score.score, lessThan(20));
      expect(score.level, NetworkQualityLevel.bad);
      expect(score.suggestions.length, greaterThanOrEqualTo(5));
    });

    test('normalises over the metrics that are present', () {
      final onlyLatencyGood = NetworkQualityEvaluator.evaluate(latency: 5);
      final onlyLatencyBad = NetworkQualityEvaluator.evaluate(latency: 900);

      expect(onlyLatencyGood.score, 100);
      expect(onlyLatencyBad.score, lessThan(40));
    });

    test('exposes raw values and sub scores', () {
      final score = NetworkQualityEvaluator.evaluate(latency: 60, download: 10);

      expect(score.metrics['latency'], 60);
      expect(score.metrics['download'], 10);
      expect(score.metrics['subScore.latency'], isNotNull);
      expect(
        score.metrics.keys.where((key) => key.startsWith('subScore.')).length,
        2,
      );
    });

    test('honours custom quality targets', () {
      const forgiving = QualityTargets(
        excellentLatency: 500,
        acceptableLatency: 1000,
      );

      final score = NetworkQualityEvaluator.evaluate(
        latency: 300,
        targets: forgiving,
      );

      expect(score.score, 100);
    });

    test('treats a saturated link as acceptable but not excellent', () {
      const strict = QualityTargets(
        excellentDownload: 100,
        acceptableDownload: 50,
      );

      final score = NetworkQualityEvaluator.evaluate(
        download: 50,
        targets: strict,
      );

      expect(score.metrics['subScore.download'], closeTo(40, 0.01));
      expect(score.score, closeTo(40, 0.01));
    });
  });
}
