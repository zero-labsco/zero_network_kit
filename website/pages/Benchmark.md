# Benchmarks / 微基准测试

`NetworkBenchmark` measures how fast the diagnostics API itself runs — useful
when deciding whether a diagnostic belongs on your startup path.

`NetworkBenchmark` 衡量诊断 API 自身的开销——可用在判断某项诊断能否放在启动路径上。

## All at once / 一次性全跑

```dart
final suite = await NetworkBenchmark.runAll(
  iterations: 20,
  warmupIterations: 3,
  host: '1.1.1.1',
  dnsDomain: 'example.com',
  port: 443,
);

for (final result in suite.results) {
  print('${result.testName.padRight(12)} '
        'avg ${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms '
        '± ${(result.standardDeviation.inMicroseconds / 1000).toStringAsFixed(2)} ms '
        '${result.operationsPerSecond.toStringAsFixed(1)} ops/s '
        'failures=${result.failures}');
}

// Look up one benchmark by name / 按名称查单个结果
print(suite['ping']?.averageDuration);
print(suite.totalDuration);
```

## Individual suites / 单个基准

```dart
await NetworkBenchmark.benchmarkConnection(iterations: 20);
await NetworkBenchmark.benchmarkPing(iterations: 20, host: '1.1.1.1');
await NetworkBenchmark.benchmarkDns(iterations: 20, domain: 'example.com');
await NetworkBenchmark.benchmarkPortCheck(iterations: 20, port: 443);
await NetworkBenchmark.benchmarkPlatformChannel(iterations: 20);
```

## Result fields / 结果字段

`BenchmarkResult`: `testName`, `iterations`, `totalDuration`, `averageDuration`,
`minDuration`, `maxDuration`, `standardDeviation`, `operationsPerSecond`,
`failures`, `timestamp`.

`BenchmarkSuiteResult`: `suiteName`, `results`, `totalDuration`, `timestamp`, and
`suite['name']`.
