# Quality Score / 质量评分

`NetworkDiagnostic.evaluateQuality()` returns a weighted 0–100 score plus a
level and human-readable suggestions, computed over whatever metrics are
available.

`NetworkDiagnostic.evaluateQuality()` 返回一个加权 0–100 分，附带等级与可读建议，
它基于当前可用的各项指标计算得出。

## Basic / 基础

```dart
final quality = await NetworkDiagnostic.evaluateQuality(
  includePing: true,
  includeDns: true,
  includeSpeedTest: true,
  includeUpload: true,
);

print('${quality.score.toStringAsFixed(1)}/100 — ${quality.level.label}');
quality.metrics.forEach((metric, value) {
  print('  $metric = ${value.toStringAsFixed(2)}');
});
for (final suggestion in quality.suggestions) {
  print('• $suggestion');
}
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `includePing` | `true` | Sample latency / jitter / loss |
| `includeDns` | `true` | Sample DNS latency |
| `includeSpeedTest` | `true` | Sample download / upload (heavy) |
| `includeUpload` | `true` | Include the upload metric |
| `pingHost` / `pingCount` | from config | Latency target |
| `dnsDomain` / `dnsServers` | from config | DNS target |
| `downloadUrl` / `uploadUrl` | from config | Bandwidth endpoints |

### Lightweight variant / 轻量变体

```dart
final quality = await NetworkDiagnostic.evaluateQuality(includeSpeedTest: false);
```

## Level thresholds / 等级阈值

`≥90` excellent · `≥75` good · `≥60` fair · `≥40` poor · otherwise bad
(`NetworkQualityLevel.fromScore`).

`≥90` 极佳 · `≥75` 良好 · `≥60` 一般 · `≥40` 较差 · 其余为极差。

## Weights / 权重

| Metric | Weight | Source |
| --- | --- | --- |
| `latency` | 0.25 | `PingResult.averageTime` |
| `jitter` | 0.10 | `PingResult.jitter` |
| `packetLoss` | 0.15 | `PingResult.packetLoss` |
| `download` | 0.25 | `SpeedTestResult.downloadSpeed` |
| `upload` | 0.15 | `SpeedTestResult.uploadSpeed` |
| `dns` | 0.10 | mean of successful `DnsTestResult.responseTimeMs` |
| `signalStrength` | 0.10 | `NetworkConnectionInfo.signalStrength` |

## Pure function / 纯函数

If you already have the metrics, skip the network entirely:

如果你已有指标，可完全跳过网络：

```dart
final score = NetworkQualityEvaluator.evaluate(
  latency: 42, jitter: 6, packetLoss: 0,
  download: 88.4, upload: 12.1, dns: 25, signalStrength: -55,
  targets: const QualityTargets(),
);
print('${score.score.toStringAsFixed(1)} → ${score.level.label}');
```

Tune the ideal values globally through `NetworkDiagnosticConfig(qualityTargets: ...)`.
调整理想值请通过 `NetworkDiagnosticConfig(qualityTargets: ...)` 全局设置。
