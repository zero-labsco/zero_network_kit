# Speed Test / 测速

`NetworkDiagnostic.runSpeedTest()` measures download and upload throughput and
samples latency during the run, reporting progress through `onProgress`.

`NetworkDiagnostic.runSpeedTest()` 测量下载与上传吞吐量，并在过程中采样延迟，通过
`onProgress` 汇报进度。

## Basic / 基础

```dart
final speed = await NetworkDiagnostic.runSpeedTest(
  includeUpload: true,
  includePing: true,
  onProgress: (progress) {
    print('${progress.phase.name}: '
          '${progress.speedMbps.toStringAsFixed(1)} Mbps '
          '(${progress.bytes} bytes, ${progress.elapsed.inMilliseconds} ms)');
  },
);

print('download : ${speed.downloadSpeed.toStringAsFixed(2)} Mbps');
print('upload   : ${speed.uploadSpeed.toStringAsFixed(2)} Mbps');
print('ping     : ${speed.ping.toStringAsFixed(1)} ms');
print('jitter   : ${speed.jitter.toStringAsFixed(2)} ms');
print('loss     : ${speed.packetLoss.toStringAsFixed(1)} %');
print('server   : ${speed.server}');
print('duration : ${speed.duration.inMilliseconds} ms');
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `downloadUrl` / `uploadUrl` | from config | Endpoints used |
| `timeout` | `config.speedTestTimeout` | Per-request timeout |
| `maxDuration` | `config.speedTestMaxDuration` | Sampling window per phase |
| `uploadPayloadBytes` | `config.uploadPayloadBytes` | Upload size |
| `pingHost` / `pingCount` | from config | Latency sampled during the test |
| `includeUpload` | `true` | Skip the upload phase |
| `includePing` | `true` | Skip the latency sample |
| `onProgress` | `null` | Called repeatedly during both phases |

Progress phases: `SpeedTestPhase.download` → `SpeedTestPhase.upload` →
`SpeedTestPhase.completed`.

进度阶段依次为 `download` → `upload` → `completed`。

## Fast, low-traffic variant / 轻量低流量变体

```dart
final quick = await NetworkDiagnostic.runSpeedTest(
  includeUpload: false,
  includePing: false,
  maxDuration: const Duration(seconds: 5),
);
```

> The default endpoints point at Cloudflare's public speed service and move real
> traffic (≈25 MB download by default). Ask for consent before running it on a
> metered connection, and override `downloadUrl` / `uploadUrl` for production.
> 默认端点指向 Cloudflare 公共服务并会产生真实流量（默认下载约 25 MB）。在按量计费
> 网络上运行前请征得同意，并为生产环境替换 `downloadUrl` / `uploadUrl`。
