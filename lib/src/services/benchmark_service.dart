import 'dart:math' as math;

import '../models/benchmark_result.dart';

/// 微基准测试执行器 / Micro-benchmark runner.
///
/// 通过多次迭代并统计耗时分布，给出平均值、极值、标准差与每秒操作数 /
/// Runs a task repeatedly and reports the mean, extremes, standard deviation and
/// throughput of the collected samples.
class BenchmarkService {
  /// 构造 [BenchmarkService] / Creates a [BenchmarkService].
  const BenchmarkService();

  /// 运行单项基准测试 / Runs a single benchmark.
  ///
  /// [warmupIterations] 次预热不计入统计，用于消除 JIT 与连接建立的噪声 /
  /// [warmupIterations] runs are excluded from the statistics to absorb JIT and
  /// connection setup noise. 任务抛出的异常会被计为 [BenchmarkResult.failures]
  /// 而不是中断整轮测试 / Exceptions thrown by [task] are counted in
  /// [BenchmarkResult.failures] instead of aborting the run.
  Future<BenchmarkResult> run({
    required String testName,
    required Future<void> Function(int iteration) task,
    int iterations = 20,
    int warmupIterations = 3,
    void Function(int completed, int total)? onProgress,
  }) async {
    final totalIterations = math.max(1, iterations);

    for (var i = 0; i < math.max(0, warmupIterations); i++) {
      try {
        await task(i);
      } catch (_) {
        // Warm-up failures are intentionally ignored.
      }
    }

    final samples = <int>[];
    var failures = 0;
    final suiteWatch = Stopwatch()..start();

    for (var i = 0; i < totalIterations; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        await task(i);
        stopwatch.stop();
        samples.add(stopwatch.elapsedMicroseconds);
      } catch (_) {
        failures += 1;
      }
      onProgress?.call(i + 1, totalIterations);
    }

    suiteWatch.stop();
    return BenchmarkResult.fromSamples(
      testName: testName,
      samples: samples,
      totalDuration: suiteWatch.elapsed,
      failures: failures,
      timestamp: DateTime.now(),
    );
  }

  /// 顺序运行一组基准测试 / Runs a group of benchmarks sequentially.
  Future<BenchmarkSuiteResult> runSuite({
    required String suiteName,
    required Map<String, Future<void> Function(int iteration)> tasks,
    int iterations = 20,
    int warmupIterations = 3,
  }) async {
    final suiteWatch = Stopwatch()..start();
    final results = <BenchmarkResult>[];
    for (final entry in tasks.entries) {
      results.add(
        await run(
          testName: entry.key,
          task: entry.value,
          iterations: iterations,
          warmupIterations: warmupIterations,
        ),
      );
    }
    suiteWatch.stop();

    return BenchmarkSuiteResult(
      suiteName: suiteName,
      results: results,
      totalDuration: suiteWatch.elapsed,
      timestamp: DateTime.now(),
    );
  }
}
