# API Guide / 接口使用指南

Every public capability of `zero_network_kit`, with copy‑paste ready examples.
本文件覆盖 `zero_network_kit` 的**全部公开功能**，每个示例都可以直接复制运行。

**English** | [简体中文](API_zh.md)

> Heads‑up / 注意：our `NetworkType` exposes `label` and `id` — there is **no**
> `displayName`. Write `connection.type.label`, not
> `connection.type.displayName`. / 本插件的 `NetworkType` 只有 `label` 与 `id`，
> **没有** `displayName`。

---

## Contents / 目录

| # | Capability / 能力 | API |
| --- | --- | --- |
| 0 | [Import & setup](#0-import--setup-引入与初始化) | `ZeroNetworkKit.init()` |
| 1 | [Which API do I need?](#1-which-api-do-i-need-该用哪个-api) | — |
| 2 | [Global configuration](#2-global-configuration-全局配置) | `NetworkDiagnosticConfig` |
| 3 | [Connectivity](#3-connectivity-连通性) | `checkConnection()` |
| 4 | [Connectivity stream](#4-connectivity-stream-连通性监听) | `onConnectivityChanged` |
| 5 | [Latency / Ping](#5-latency--ping-延迟探测) | `ping()` |
| 6 | [DNS](#6-dns-解析) | `resolve()` |
| 7 | [Ports](#7-ports-端口检测) | `checkPort()` / `scanPorts()` |
| 8 | [Speed test](#8-speed-test-测速) | `runSpeedTest()` |
| 9 | [Quality score](#9-quality-score-质量评分) | `evaluateQuality()` |
| 10 | [Full report](#10-full-report-汇总报告) | `diagnose()` |
| 11 | [Benchmarks](#11-benchmarks-微基准测试) | `NetworkBenchmark.runAll()` |
| 12 | [Native platform data](#12-native-platform-data-原生平台信息) | `getPlatformVersion()` |
| 13 | [JSON serialisation](#13-json-serialisation-序列化) | `toMap()` |
| 14 | [Dependency injection & tests](#14-dependency-injection--tests-注入与测试) | `configure()` |
| 15 | [Model reference](#15-model-reference-模型字段速查) | — |
| 16 | [Gotchas](#16-gotchas-常见陷阱) | — |

---

## 0. Import & setup / 引入与初始化

```dart
import 'package:zero_network_kit/zero_network_kit.dart';
```

That single import exposes everything. Initialisation is **optional** — every
API falls back to built‑in defaults.
一个 import 即可；初始化是**可选的**，不调用也能直接用（走内置默认值）。

```dart
void main() {
  // Optional. Apply your own global defaults once.
  // 可选：全局定制一次默认参数。
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(pingHost: '1.1.1.1'),
  );
  runApp(const MyApp());
}
```

Release the HTTP client the plugin owns when your app shuts down:

```dart
await ZeroNetworkKit.dispose();
```

Inspecting the current state:

```dart
ZeroNetworkKit.isInitialized; // false until init() runs
ZeroNetworkKit.config;        // the effective NetworkDiagnosticConfig
```

## 1. Which API do I need? / 该用哪个 API？

| I want to know… | Call |
| --- | --- |
| Am I online, and over what transport? | `NetworkDiagnostic.checkConnection()` |
| React to Wi‑Fi ⇄ cellular switches | `NetworkDiagnostic.onConnectivityChanged` |
| Latency, jitter, packet loss | `NetworkDiagnostic.ping()` |
| Is DNS slow or broken? | `NetworkDiagnostic.resolve()` |
| Is `host:port` reachable? | `NetworkDiagnostic.checkPort()` |
| Which of these ports are open? | `NetworkDiagnostic.scanPorts()` |
| How fast is down/up? | `NetworkDiagnostic.runSpeedTest()` |
| One number for “good or bad” | `NetworkDiagnostic.evaluateQuality()` |
| Everything at once, as a report | `NetworkDiagnostic.diagnose()` |
| Is the diagnostics API itself expensive? | `NetworkBenchmark.runAll()` |
| Native version / SSID / gateway / MAC | `ZeroNetworkKit.getPlatformVersion()`, `getNativeNetworkDetails()` |

## 2. Global configuration / 全局配置

`NetworkDiagnosticConfig` centralises every default. Override only what you
need; the rest keep the defaults below.
`NetworkDiagnosticConfig` 集中了全部默认参数，只需覆盖你关心的字段。

```dart
ZeroNetworkKit.init(
  config: const NetworkDiagnosticConfig(
    pingHost: '1.1.1.1',
    pingPort: 443,
    pingCount: 5,
    dnsDomain: 'example.com',
    dnsServers: <String>['1.1.1.1', '8.8.8.8'],
    downloadUrl: 'https://my-cdn.example.com/speedtest.bin',
    uploadUrl: 'https://my-cdn.example.com/upload',
  ),
);
```

| Field | Default | Meaning |
| --- | --- | --- |
| `pingHost` | `'1.1.1.1'` | Default ping / port‑scan target |
| `pingPort` | `443` | Port used by the TCP ping |
| `pingCount` | `4` | Probes per ping run |
| `pingTimeout` | `3s` | Timeout of one probe |
| `pingInterval` | `200ms` | Delay between probes |
| `dnsDomain` | `'www.google.com'` | Default domain for DNS tests |
| `dnsServers` | `['1.1.1.1', '8.8.8.8', '114.114.114.114']` | Servers queried by default |
| `dnsTimeout` | `5s` | Timeout per DNS server |
| `downloadUrl` | Cloudflare `__down?bytes=25000000` | Download endpoint |
| `uploadUrl` | Cloudflare `__up` | Upload endpoint |
| `uploadPayloadBytes` | `1048576` (1 MiB) | Upload payload size |
| `speedTestTimeout` | `30s` | Per‑request timeout |
| `speedTestMaxDuration` | `10s` | Sampling window per phase |
| `portCheckTimeout` | `3s` | Timeout of one port check |
| `probePorts` | `[80, 443]` | Ports used by `scanPorts()` by default |
| `qualityTargets` | `const QualityTargets()` | Ideal values for scoring |

The defaults point at public Cloudflare speed endpoints. Swap them for your own
before shipping production traffic.
默认测速端点是 Cloudflare 的公共服务，正式项目请替换为自建端点。

### Quality targets / 质量评分理想值

```dart
const NetworkDiagnosticConfig(
  qualityTargets: QualityTargets(
    excellentLatency: 30,     // ms
    acceptableLatency: 150,   // ms
    excellentJitter: 5,       // ms
    acceptableJitter: 40,     // ms
    acceptablePacketLoss: 5,  // %
    excellentDownload: 50,    // Mbps
    acceptableDownload: 5,    // Mbps
    excellentUpload: 20,      // Mbps
    acceptableUpload: 2,      // Mbps
    excellentDns: 30,         // ms
    acceptableDns: 200,       // ms
  ),
);
```

## 3. Connectivity / 连通性

```dart
final connection = await NetworkDiagnostic.checkConnection();

print('type       : ${connection.type.label}'); // Wi-Fi / Mobile / Ethernet …
print('connected  : ${connection.isConnected}');
print('ipv4       : ${connection.ipAddress}');
print('ipv6       : ${connection.ipv6Address}');
print('gateway    : ${connection.gateway}');
print('ssid       : ${connection.ssid}');
print('rssi       : ${connection.signalStrength} dBm');
print('mac        : ${connection.macAddress}');
print('vpn        : ${connection.isVpn}');
print('timestamp  : ${connection.timestamp}');
```

Parameters:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `includeNativeDetails` | `true` | Also read SSID / gateway / MAC / VPN from the native side |
| `probeReachability` | `false` | Additionally make a real request and fill `isReachable` |
| `probeTimeout` | `3s` | Timeout of that reachability probe |

```dart
// Skip the native channel (cheapest call — good on hot paths).
final quick = await NetworkDiagnostic.checkConnection(
  includeNativeDetails: false,
);

// Prove the network actually reaches the internet, not just that a NIC is up.
final verified = await NetworkDiagnostic.checkConnection(
  probeReachability: true,
  probeTimeout: const Duration(seconds: 5),
);

if (verified.isReachable == false) {
  print('Interface is up but the internet is unreachable.');
}
```

### Connectivity-only: minimal example / 仅连通性：最小示例

If all you need is "am I online, on what transport, what IP, and react to
changes", you only need sections 3 and 4 — **no `init()` required**, and you can
ignore ping / DNS / speed entirely.
如果只需要「在不在線、走什么網络、IP 是多少、切换时通知」，只用第 3、4 节即可——
**无需 `init()`**，也不必调用 ping / DNS / 测速。

One-shot snapshot (plain Dart, no widget):
一次性快照（纯 Dart，无需 Widget）：

```dart
final c = await NetworkDiagnostic.checkConnection();
print('${c.type.label} · connected=${c.isConnected} · ip=${c.ipAddress}');
```

A minimal Flutter screen that shows the current connection and updates on every
switch (Wi-Fi ⇄ cellular, etc.):
一个最小的 Flutter 页面，展示当前连接并在切换时刷新（Wi-Fi ⇄ 蜂窝等）：

```dart
import 'package:flutter/material.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

class ConnectivityScreen extends StatelessWidget {
  const ConnectivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkConnectionInfo>(
      stream: NetworkDiagnostic.onConnectivityChanged,
      builder: (context, snap) {
        final c = snap.data;
        if (c == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            ListTile(title: const Text('Type / 类型'), trailing: Text(c.type.label)),
            ListTile(title: const Text('Online / 在线'), trailing: Text('${c.isConnected}')),
            ListTile(title: const Text('IPv4'), trailing: Text(c.ipAddress ?? '—')),
            ListTile(title: const Text('IPv6'), trailing: Text(c.ipv6Address ?? '—')),
          ],
        );
      },
    );
  }
}
```

> `ZeroNetworkKit.init()` is optional and only needed to override defaults
> (e.g. a custom reachability host). Connectivity alone works with the
> built-in defaults.
> `ZeroNetworkKit.init()` 是可选的，仅在想覆盖默认参数时才需要；单用连通性直接走内置默认值即可。

## 4. Connectivity stream / 连通性监听

```dart
final subscription = NetworkDiagnostic.onConnectivityChanged.listen(
  (info) => print('now on ${info.type.id} · ${info.ipAddress}'),
);

// Later:
await subscription.cancel();
```

In a widget:

```dart
StreamBuilder<NetworkConnectionInfo>(
  stream: NetworkDiagnostic.onConnectivityChanged,
  builder: (context, snapshot) {
    final info = snapshot.data;
    if (info == null) return const Text('Checking…');
    return Text('${info.type.label} · ${info.isConnected}');
  },
)
```

## 5. Latency / Ping / 延迟探测

```dart
final ping = await NetworkDiagnostic.ping(
  host: '1.1.1.1',
  count: 5,
  timeout: const Duration(seconds: 2),
  interval: const Duration(milliseconds: 200),
  port: 443,
);

print('received : ${ping.received}/${ping.sent}');
print('loss     : ${ping.packetLoss.toStringAsFixed(1)} %');
print('min/avg/max: ${ping.minTime.toStringAsFixed(1)} / '
      '${ping.averageTime.toStringAsFixed(1)} / '
      '${ping.maxTime.toStringAsFixed(1)} ms');
print('jitter   : ${ping.jitter.toStringAsFixed(2)} ms');
print('samples  : ${ping.times}');
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `host` | `config.pingHost` | Target host |
| `count` | `config.pingCount` | Number of probes |
| `timeout` | `config.pingTimeout` | Per‑probe timeout |
| `interval` | `config.pingInterval` | Delay between probes |
| `port` | `config.pingPort` | TCP port probed in `PingMode.tcp` |
| `mode` | `PingMode.tcp` | `PingMode.tcp` or `PingMode.icmp` |

### TCP vs ICMP

`PingMode.tcp` performs a TCP handshake to `host:port` — the portable
equivalent of ICMP, and the only mode available on Android/iOS.
`PingMode.tcp` 通过 TCP 握手到 `host:port` 测量往返，是移动端唯一可用方式。

```dart
// Desktop only — falls back gracefully if the `ping` binary is unavailable.
await NetworkDiagnostic.ping(host: '1.1.1.1', count: 4, mode: PingMode.icmp);
```

`ping.isSuccess` is `true` when at least one probe answered; check it before
trusting the averages.
至少一次成功响应时 `isSuccess` 为 `true`，读平均值前建议先判断它。

## 6. DNS / DNS 解析

```dart
final results = await NetworkDiagnostic.resolve(
  domain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8', '114.114.114.114'],
  timeout: const Duration(seconds: 5),
  concurrent: true,
  includeSystemResolver: true,
);

for (final r in results) {
  if (r.isSuccess) {
    print('${r.server.padRight(16)} → ${r.resolvedIps.join(", ")} '
          '(${r.responseTimeMs.toStringAsFixed(1)} ms)');
  } else {
    print('${r.server.padRight(16)} ✗ ${r.errorMessage}');
  }
}
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `domain` | `config.dnsDomain` | Domain to resolve |
| `dnsServers` | `config.dnsServers` | Servers queried in parallel (or in series) |
| `timeout` | `config.dnsTimeout` | Timeout of one query |
| `concurrent` | `true` | Query all servers at once |
| `includeSystemResolver` | `false` | Also add a `system` row |

Notes / 说明:

- A row with `server == 'system'` comes from the OS resolver; the others are
  raw UDP queries against the listed IPs, encoded by the built‑in `DnsPacket`
  wire codec. / `server == 'system'` 的行来自系统解析器，其余是对指定 IP 的原始
  UDP 查询，由内置 `DnsPacket` 编解码。
- `includeSystemResolver` defaults to **`false`** at the facade level — pass
  `true` to include it. / 门面层默认 **不** 包含系统解析器。
- Compare servers to find the fastest one: / 可以借此挑出最快的 DNS：

```dart
final fastest = results
    .where((r) => r.isSuccess)
    .reduce((a, b) => a.responseTimeMs <= b.responseTimeMs ? a : b);
print('fastest resolver: ${fastest.server}');
```

## 7. Ports / 端口检测

```dart
// Single port → boolean convenience
final open = await NetworkDiagnostic.isPortOpen(
  host: 'example.com',
  port: 443,
  timeout: const Duration(seconds: 3),
);
print(open ? 'HTTPS reachable' : 'HTTPS unreachable');
```

```dart
// Many ports → per-port results with RTT and error message
final scan = await NetworkDiagnostic.scanPorts(
  host: 'example.com',
  ports: const <int>[22, 80, 443, 8080, 8443],
  concurrency: 8,
);

for (final r in scan) {
  print('${r.host}:${r.port} '
        '${r.isOpen ? "open" : "closed"} '
        '${r.responseTimeMs.toStringAsFixed(1)} ms '
        '${r.errorMessage ?? ""}');
}
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `ports` (`scanPorts`) | `config.probePorts` (`[80, 443]`) | Ports to probe |
| `concurrency` | `12` | Max in‑flight connections |
| `timeout` | `config.portCheckTimeout` | Timeout per port |

> `checkPort()` returns a **`PortCheckResult`** (with `isOpen`, `responseTimeMs`
> and `errorMessage`); use `isPortOpen()` for a plain boolean. When you need the
> round‑trip time or the failure reason for a single port, call `checkPort()`
> directly or pass a one‑element list to `scanPorts()`:
> `scanPorts(host: 'example.com', ports: [443]).first`.
> `checkPort()` 返回 **`PortCheckResult`**（含 `isOpen`、`responseTimeMs`、
> `errorMessage`）；单端口布尔诉求请用 `isPortOpen()`。需要 RTT 或失败原因时
> 可直接调用 `checkPort()`，或给 `scanPorts(..., ports: [443])` 取单条结果。

## 8. Speed test / 测速

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
| `timeout` | `config.speedTestTimeout` | Per‑request timeout |
| `maxDuration` | `config.speedTestMaxDuration` | Sampling window per phase |
| `uploadPayloadBytes` | `config.uploadPayloadBytes` | Upload size |
| `pingHost` / `pingCount` | from config | Latency sampled during the test |
| `includeUpload` | `true` | Skip the upload phase |
| `includePing` | `true` | Skip the latency sample |
| `onProgress` | `null` | Called repeatedly during both phases |

Progress phases: `SpeedTestPhase.download` → `SpeedTestPhase.upload` →
`SpeedTestPhase.completed`.
进度阶段依次为 `download` → `upload` → `completed`。

Fast, low‑traffic variant (skips upload and latency):

```dart
final quick = await NetworkDiagnostic.runSpeedTest(
  includeUpload: false,
  includePing: false,
  maxDuration: const Duration(seconds: 5),
);
```

## 9. Quality score / 质量评分

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

Lightweight variant (no bandwidth consumed):

```dart
final quality = await NetworkDiagnostic.evaluateQuality(includeSpeedTest: false);
```

To change the ideal values used for scoring, apply them globally through the
config — there is no per‑call target parameter:

```dart
ZeroNetworkKit.init(
  config: const NetworkDiagnosticConfig(
    qualityTargets: QualityTargets(excellentLatency: 20, acceptableLatency: 100),
  ),
);
```

If you already have the metrics, skip the network entirely and score them with
the pure function:

```dart
final score = NetworkQualityEvaluator.evaluate(
  latency: 42,
  jitter: 6,
  packetLoss: 0,
  download: 88.4,
  upload: 12.1,
  dns: 25,
  signalStrength: -55,
  targets: const QualityTargets(),
);

print('${score.score.toStringAsFixed(1)} → ${score.level.label}');
print(score.suggestions);
```

Level thresholds: `≥90` excellent · `≥75` good · `≥60` fair · `≥40` poor ·
otherwise bad (`NetworkQualityLevel.fromScore`).
等级阈值：`≥90` 极佳 · `≥75` 良好 · `≥60` 一般 · `≥40` 较差 · 其余为极差。

Weights applied to whatever metrics are available:

| Metric key in `quality.metrics` | Weight | Source |
| --- | --- | --- |
| `latency` | 0.25 | `PingResult.averageTime` |
| `jitter` | 0.10 | `PingResult.jitter` |
| `packetLoss` | 0.15 | `PingResult.packetLoss` |
| `download` | 0.25 | `SpeedTestResult.downloadSpeed` |
| `upload` | 0.15 | `SpeedTestResult.uploadSpeed` |
| `dns` | 0.10 | mean of successful `DnsTestResult.responseTimeMs` |
| `signalStrength` | 0.10 | `NetworkConnectionInfo.signalStrength` |

## 10. Full report / 汇总报告

```dart
final report = await NetworkDiagnostic.diagnose(
  includePing: true,
  includeDns: true,
  includePorts: true,
  includeSpeedTest: true,
  includeUpload: true,
  host: '1.1.1.1',
  dnsDomain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8'],
  ports: const <int>[80, 443],
);

print(report);                                  // one-line summary
print(report.connection.type.label);
print(report.ping?.averageTime);
print(report.dnsResults.length);
print(report.portResults.where((p) => p.isOpen).length);
print(report.speedTest?.downloadSpeed);
print(report.quality.level.label);
```

`includePorts` defaults to `false`, so a default run does not scan ports.
A failing sub‑test never aborts the run — its field is simply absent/`null`.
`includePorts` 默认 `false`；任何子项失败都不会中断整体流程，对应字段保持空。

## 11. Benchmarks / 微基准测试

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

// Look up one benchmark by name:
print(suite['ping']?.averageDuration);
print(suite.totalDuration);
```

Individual suites:

```dart
await NetworkBenchmark.benchmarkConnection(iterations: 20);
await NetworkBenchmark.benchmarkPing(iterations: 20, host: '1.1.1.1');
await NetworkBenchmark.benchmarkDns(iterations: 20, domain: 'example.com');
await NetworkBenchmark.benchmarkPortCheck(iterations: 20, port: 443);
await NetworkBenchmark.benchmarkPlatformChannel(iterations: 20);
```

Use this to decide whether a diagnostic belongs on your startup path.
用它来判断某项诊断能否放在启动路径上。

## 12. Native platform data / 原生平台信息

```dart
final version = await ZeroNetworkKit.getPlatformVersion();
print(version); // e.g. 'Android 14' / 'iOS 18.0'

final details = await ZeroNetworkKit.getNativeNetworkDetails();
if (details != null) {
  print(details); // SSID, BSSID, gateway, MAC, VPN flag, RSSI …
}
```

The same methods exist on `NetworkDiagnostic` for convenience:

```dart
await NetworkDiagnostic.getPlatformVersion();
await NetworkDiagnostic.getNativeNetworkDetails();
```

Both return `null` (or a partial map) when the platform has no such data or the
permission is missing — they never throw.
缺少权限或平台无此数据时返回 `null`，不会抛异常。

## 13. JSON serialisation / 序列化

Every result object implements `toMap()` and is JSON encodable:

```dart
import 'dart:convert';

final report = await NetworkDiagnostic.diagnose(includeSpeedTest: false);
final json = jsonEncode(report.toMap());
print(json);

// Round-trip a connection snapshot.
final decoded = NetworkConnectionInfo.fromMap(jsonDecode(jsonEncode(
  report.connection.toMap(),
)) as Map<Object?, Object?>);
```

| Type | Serialisation |
| --- | --- |
| `NetworkConnectionInfo` | `toMap()` + `fromMap()` |
| `PingResult` | `toMap()` |
| `DnsTestResult` | `toMap()` |
| `PortCheckResult` | `toMap()` |
| `SpeedTestResult` | `toMap()` |
| `NetworkQualityScore` | `toMap()` |
| `NetworkDiagnosticReport` | `toMap()` |
| `BenchmarkResult` / `BenchmarkSuiteResult` | `toMap()` |

## 14. Dependency injection & tests / 注入与测试

Every service accepts its collaborators, so your integration points are
unit‑testable without touching the network.
每个服务都支持注入协作对象，可以完全脱离网络做单测。

```dart
class FakeConnectivityAdapter implements ConnectivityAdapter {
  @override
  Future<List<String>> checkConnectivity() async => <String>['wifi'];

  @override
  Stream<List<String>> get onConnectivityChanged => const Stream.empty();
}

NetworkDiagnostic.configure(
  config: const NetworkDiagnosticConfig(pingHost: '127.0.0.1'),
  connectivity: ConnectivityService(adapter: FakeConnectivityAdapter()),
  ping: PingService(),
  dns: DnsService(),
  ports: PortService(),
  speedTest: SpeedTestService(client: fakeClient),
);

// Restore defaults afterwards.
NetworkDiagnostic.reset();
```

Swap individual services directly when you prefer:

```dart
NetworkDiagnostic.pingService = MyFakePingService();
NetworkDiagnostic.dnsService = MyFakeDnsService();
```

## 15. Model reference / 模型字段速查

### `NetworkType`

| Member | Notes |
| --- | --- |
| values | `none`, `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `other` |
| `label` | Human readable: `'Wi-Fi'`, `'Mobile'`, … |
| `id` | Stable English identifier (`name`), safe to persist |
| `isConnected` | `true` unless `none` |
| `NetworkType.fromRaw(Object?)` | Parses a raw platform string |

### `NetworkConnectionInfo`

`isConnected`, `type`, `ssid`, `signalStrength` (dBm), `ipAddress`,
`ipv6Address`, `gateway`, `macAddress`, `isVpn`, `isReachable`, `timestamp`,
plus `copyWith({bool? isReachable})`.

### `PingResult`

Fields `host`, `port`, `mode`, `sent`, `received`, `times`, `timestamp`;
derived getters `lost`, `packetLoss` (%), `minTime`, `maxTime`, `averageTime`,
`jitter`, `isSuccess`.

### `DnsTestResult`

Fields `server`, `domain`, `isSuccess`, `responseTime`, `resolvedIps`,
`errorMessage`, `timestamp`; derived `responseTimeMs`, `primaryAddress`.

### `PortCheckResult`

Fields `host`, `port`, `isOpen`, `responseTime`, `errorMessage`, `timestamp`;
derived `responseTimeMs`.

### `SpeedTestResult`

Fields `downloadSpeed`, `uploadSpeed` (Mbps), `ping` (ms), `jitter` (ms),
`packetLoss` (%), `downloadedBytes`, `uploadedBytes`, `downloadDuration`,
`uploadDuration`, `server`, `timestamp`; derived `duration`; static helper
`SpeedTestResult.mbpsFromBytes(bytes, elapsed)`.

### `SpeedTestProgress` / `SpeedTestPhase`

`phase` (`download`, `upload`, `completed`), `bytes`, `elapsed`, `speedMbps`.

### `NetworkQualityScore` / `NetworkQualityLevel`

`score` (0–100), `level`, `metrics` (`Map<String, double>`), `suggestions`,
`timestamp`; `NetworkQualityLevel.fromScore(double)`, `level.label`.

### `NetworkDiagnosticReport`

`connection`, `ping`, `dnsResults`, `portResults`, `speedTest`, `quality`,
`timestamp`.

### `BenchmarkResult` / `BenchmarkSuiteResult`

`BenchmarkResult`: `testName`, `iterations`, `totalDuration`,
`averageDuration`, `minDuration`, `maxDuration`, `standardDeviation`,
`operationsPerSecond`, `failures`, `timestamp`.
`BenchmarkSuiteResult`: `suiteName`, `results`, `totalDuration`, `timestamp`,
and `suite['name']`.
Public constructor helpers: `BenchmarkResult.fromSamples(...)`.

## 16. Gotchas / 常见陷阱

1. **`type.label`, not `displayName`.** `NetworkType` exposes `label` / `id`.
2. **`checkPort()` returns `bool`.** Use `scanPorts(..., ports: [p])` when you
   need RTT or the error message.
3. **`includeSystemResolver` defaults to `false`.** Pass `true` to add the
   `system` DNS row.
4. **A TCP ping needs a listening port.** Probing `host` with `port: 443`
   fails if that host does not accept TCP/443 — that is “filtered”, not
   “offline”. Use `mode: PingMode.icmp` on desktop to get closer to real ICMP.
5. **`PingMode.icmp` is desktop‑only** and silently degrades when the `ping`
   binary is unavailable.
6. **The speed test moves real traffic** (≈25 MB download by default). Ask for
   consent before running it on a metered connection.
7. **Missing permissions degrade, they never throw.** A missing location
   permission yields `ssid == null`; the rest of the snapshot still arrives.
8. **`includePorts` is `false` by default** in `diagnose()`.
9. **`init()` is optional, but `dispose()` only closes the client the plugin
   owns** — an `httpClient` you injected stays open, so close it yourself.

---

[简体中文版](API_zh.md) · [README](README.md) · [CHANGELOG](CHANGELOG.md) · [MPL-2.0](LICENSE)
