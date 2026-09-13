import 'dart:math' as math;

/// 单项基准测试结果 / Result of a single micro-benchmark.
class BenchmarkResult {
  /// 构造 [BenchmarkResult] / Creates a [BenchmarkResult].
  const BenchmarkResult({
    required this.testName,
    required this.iterations,
    required this.totalDuration,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.standardDeviation,
    required this.operationsPerSecond,
    required this.timestamp,
    this.failures = 0,
  });

  /// 测试名称 / Name of the benchmark.
  final String testName;

  /// 有效迭代次数 / Number of successful iterations.
  final int iterations;

  /// 有效迭代总耗时 / Total time spent in successful iterations.
  final Duration totalDuration;

  /// 单次平均耗时 / Mean duration of one iteration.
  final Duration averageDuration;

  /// 单次最短耗时 / Fastest iteration.
  final Duration minDuration;

  /// 单次最长耗时 / Slowest iteration.
  final Duration maxDuration;

  /// 耗时标准差 / Standard deviation of the iteration durations.
  final Duration standardDeviation;

  /// 每秒可执行次数 / Throughput expressed as operations per second.
  final double operationsPerSecond;

  /// 抛出异常的迭代次数 / Iterations that threw.
  final int failures;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 由耗时样本计算统计量 / Computes the statistics from raw samples.
  ///
  /// [samples] 为标准化的单次耗时（微秒）/ [samples] holds per-iteration
  /// durations in microseconds.
  factory BenchmarkResult.fromSamples({
    required String testName,
    required List<int> samples,
    required Duration totalDuration,
    required DateTime timestamp,
    int failures = 0,
  }) {
    if (samples.isEmpty) {
      return BenchmarkResult(
        testName: testName,
        iterations: 0,
        totalDuration: totalDuration,
        averageDuration: Duration.zero,
        minDuration: Duration.zero,
        maxDuration: Duration.zero,
        standardDeviation: Duration.zero,
        operationsPerSecond: 0,
        failures: failures,
        timestamp: timestamp,
      );
    }

    final sum = samples.fold<int>(0, (previous, value) => previous + value);
    final average = sum / samples.length;
    final variance =
        samples
            .map((value) {
              final diff = value - average;
              return diff * diff;
            })
            .fold<double>(0, (previous, value) => previous + value) /
        samples.length;
    final totalSeconds =
        totalDuration.inMicroseconds / Duration.microsecondsPerSecond;
    final minSample = samples.reduce(math.min);

    return BenchmarkResult(
      testName: testName,
      iterations: samples.length,
      totalDuration: totalDuration,
      averageDuration: Duration(microseconds: average.round()),
      minDuration: Duration(microseconds: minSample),
      maxDuration: Duration(microseconds: samples.reduce(math.max)),
      standardDeviation: Duration(
        microseconds: variance.isNaN ? 0 : math.sqrt(variance).round(),
      ),
      operationsPerSecond: totalSeconds <= 0
          ? 0
          : samples.length / totalSeconds,
      failures: failures,
      timestamp: timestamp,
    );
  }

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'testName': testName,
    'iterations': iterations,
    'totalDurationMs': totalDuration.inMicroseconds / 1000,
    'averageDurationMs': averageDuration.inMicroseconds / 1000,
    'minDurationMs': minDuration.inMicroseconds / 1000,
    'maxDurationMs': maxDuration.inMicroseconds / 1000,
    'standardDeviationMs': standardDeviation.inMicroseconds / 1000,
    'operationsPerSecond': operationsPerSecond,
    'failures': failures,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'BenchmarkResult($testName, iterations: $iterations, '
      'avg: ${(averageDuration.inMicroseconds / 1000).toStringAsFixed(2)}ms, '
      'ops/s: ${operationsPerSecond.toStringAsFixed(1)})';
}

/// 一组基准测试结果 / A suite of benchmark results.
class BenchmarkSuiteResult {
  /// 构造 [BenchmarkSuiteResult] / Creates a [BenchmarkSuiteResult].
  const BenchmarkSuiteResult({
    required this.suiteName,
    required this.results,
    required this.totalDuration,
    required this.timestamp,
  });

  /// 套件名称 / Name of the suite.
  final String suiteName;

  /// 各单项结果 / Individual benchmark results.
  final List<BenchmarkResult> results;

  /// 套件总耗时 / Total duration of the suite.
  final Duration totalDuration;

  /// 完成时间 / Completion timestamp.
  final DateTime timestamp;

  /// 按名称读取单项结果 / Looks up one benchmark result by name.
  BenchmarkResult? operator [](String testName) {
    for (final result in results) {
      if (result.testName == testName) return result;
    }
    return null;
  }

  /// 序列化为可 JSON 编码的 Map / Serialises to a JSON encodable map.
  Map<String, Object?> toMap() => <String, Object?>{
    'suiteName': suiteName,
    'results': results.map((result) => result.toMap()).toList(),
    'totalDurationMs': totalDuration.inMicroseconds / 1000,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      'BenchmarkSuiteResult($suiteName, ${results.length} benchmarks, '
      '${(totalDuration.inMicroseconds / 1000).toStringAsFixed(0)}ms)';
}
