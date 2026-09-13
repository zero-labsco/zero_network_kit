# zero_network_kit

<div align="center">

**English** &nbsp;|&nbsp; [简体中文](README_zh.md)

</div>

A Flutter plugin for **network diagnostics**: connectivity inspection, latency
probing, DNS resolution, port checks, bandwidth measurement, quality scoring and
micro-benchmarks — for Android, iOS, macOS, Windows, Linux and Web (partial).

[![pub version](https://img.shields.io/pub/v/zero_network_kit.svg)](https://pub.dev/packages/zero_network_kit)
[![pub points](https://img.shields.io/pub/points/zero_network_kit.svg)](https://pub.dev/packages/zero_network_kit/score)
[![CI](https://github.com/zero-labsco/zero_network_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_network_kit/actions/workflows/ci.yml)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://github.com/zero-labsco/zero_network_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-green.svg)](https://pub.dev/packages/zero_network_kit)
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 Upgrade recommended:** `1.0.1` adds partial Web support — the plugin now compiles and runs in the browser, and the capabilities the sandbox forbids degrade gracefully instead of failing. It also fixes the speed test on the web. Upgrade to `^1.0.1`.

🌐 **[Official Website](https://www.zerolabsco.com/)** &nbsp;·&nbsp; 📦 **[View on pub.dev](https://pub.dev/packages/zero_network_kit)** &nbsp;·&nbsp; 🔗 **[View on GitHub](https://github.com/zero-labsco/zero_network_kit)**

---

## Table of Contents

- [Features](#features)
- [Getting started](#getting-started)
  - [Android permissions](#android-permissions)
- [Usage](#usage)
  - [Connectivity](#connectivity)
  - [Ping](#ping)
  - [DNS](#dns)
  - [Speed test](#speed-test)
  - [Ports](#ports)
  - [Quality score](#quality-score)
  - [Full report](#full-report)
  - [Benchmarks](#benchmarks)
- [Testing your own code against it](#testing-your-own-code-against-it)
- [Platform support](#platform-support)
- [Documentation](#documentation)
- [License](#license)

---

## Features

| Capability | API | Notes |
| --- | --- | --- |
| Connectivity | `NetworkDiagnostic.checkConnection()` | Transport, IPv4/IPv6, gateway, SSID, RSSI, MAC, VPN |
| Connectivity stream | `NetworkDiagnostic.onConnectivityChanged` | Emits a fresh snapshot on every change |
| Latency | `NetworkDiagnostic.ping()` | TCP handshake RTT everywhere; system ICMP on desktop |
| DNS | `NetworkDiagnostic.resolve()` | `system` resolver + raw UDP against explicit servers |
| Bandwidth | `NetworkDiagnostic.runSpeedTest()` | Download/upload throughput with progress callbacks |
| Ports | `NetworkDiagnostic.checkPort()` / `scanPorts()` | Bounded-concurrency TCP reachability |
| Quality | `NetworkDiagnostic.evaluateQuality()` | Weighted 0–100 score + level + suggestions |
| Full report | `NetworkDiagnostic.diagnose()` | One-shot aggregate of every probe |
| Capabilities | `NetworkDiagnostic.capabilities` | Query-then-call; hide unsupported cards (e.g. SSID on desktop) |
| Benchmarks | `NetworkBenchmark.runAll()` | Measures how fast the diagnostics API itself runs |

Design goals:

- **Hermetic unit tests** — every service accepts injected collaborators
  (`ConnectivityAdapter`, `http.Client`, `PingService`, …), so the whole test
  suite runs without touching the network.
- **No hidden state** — results are immutable value objects with `toMap()`.
- **Graceful degradation** — a missing permission or an unreachable sub-service
  never throws through the public API; the corresponding field stays `null`.

## Getting started

```yaml
dependencies:
  zero_network_kit: ^1.0.1
```

### Android permissions

The plugin manifest already declares `INTERNET`, `ACCESS_NETWORK_STATE` and
`ACCESS_WIFI_STATE`. Reading the Wi-Fi **SSID** additionally requires location
permission (`ACCESS_FINE_LOCATION`) on Android 8.1+ and the *Access WiFi
Information* entitlement plus location authorisation on iOS. Without it the
snapshot simply reports `ssid: null`.

## Usage

The snippets below cover the common paths. For every method, parameter, default
and result field, see the **[API guide](API.md)**.

```dart
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  // Optional: apply global defaults once.
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(
      pingHost: '1.1.1.1',
      dnsServers: <String>['1.1.1.1', '8.8.8.8'],
    ),
  );
  runApp(const MyApp());
}
```

### Connectivity

```dart
final info = await NetworkDiagnostic.checkConnection(probeReachability: true);

print('${info.type.label} · ${info.ipAddress} · ${info.signalStrength} dBm');
print('gateway=${info.gateway} vpn=${info.isVpn} reachable=${info.isReachable}');

await for (final change in NetworkDiagnostic.onConnectivityChanged) {
  print('now on ${change.type.id}');
}
```

> **Just need connectivity?** You don't need `init()` or any of the other APIs —
> `checkConnection()` and `onConnectivityChanged` work out of the box. See the
> *Connectivity-only: minimal example* in the Connectivity chapter of
> [API.md](API.md).

### Ping

```dart
final result = await NetworkDiagnostic.ping(host: '1.1.1.1', count: 5);

print('${result.received}/${result.sent} replies, '
      'loss ${result.packetLoss.toStringAsFixed(1)}%, '
      'avg ${result.averageTime.toStringAsFixed(1)} ms, '
      'jitter ${result.jitter.toStringAsFixed(2)} ms');
```

On desktop you can switch to the system ICMP binary:

```dart
await NetworkDiagnostic.ping(host: '1.1.1.1', mode: PingMode.icmp);
```

### DNS

```dart
final results = await NetworkDiagnostic.resolve(
  domain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8'],
  includeSystemResolver: true,
);

for (final r in results) {
  print('${r.server}: ${r.isSuccess ? r.resolvedIps.join(", ") : r.errorMessage}'
        ' (${r.responseTimeMs.toStringAsFixed(1)} ms)');
}
```

### Speed test

```dart
final speed = await NetworkDiagnostic.runSpeedTest(
  onProgress: (progress) => print(
    '${progress.phase.name}: ${progress.speedMbps.toStringAsFixed(1)} Mbps',
  ),
);

print('↓ ${speed.downloadSpeed.toStringAsFixed(2)} Mbps  '
      '↑ ${speed.uploadSpeed.toStringAsFixed(2)} Mbps');
```

Download and upload phases write a meaningful amount of traffic. Defaults point
at the public Cloudflare speed endpoints; override `downloadUrl` / `uploadUrl`
to use your own.

### Ports

```dart
if (await NetworkDiagnostic.isPortOpen(host: 'example.com', port: 443)) {
  print('HTTPS reachable');
}

final scan = await NetworkDiagnostic.scanPorts(
  host: 'example.com',
  ports: const <int>[22, 80, 443, 8080],
  concurrency: 8,
);
```

### Quality score

```dart
final score = await NetworkDiagnostic.evaluateQuality(includeSpeedTest: false);

print('${score.score}/100 (${score.level.label})');
for (final suggestion in score.suggestions) {
  print('• $suggestion');
}
```

The score is a weighted average of the metrics that are available:

| Metric | Weight | Source |
| --- | --- | --- |
| `latency` | 0.25 | `PingResult.averageTime` |
| `jitter` | 0.10 | `PingResult.jitter` |
| `packetLoss` | 0.15 | `PingResult.packetLoss` |
| `download` | 0.25 | `SpeedTestResult.downloadSpeed` |
| `upload` | 0.15 | `SpeedTestResult.uploadSpeed` |
| `dns` | 0.10 | mean successful `DnsTestResult.responseTimeMs` |
| `signalStrength` | 0.10 | `NetworkConnectionInfo.signalStrength` |

Tune the ideal values with `NetworkDiagnosticConfig(qualityTargets: ...)`.

### Full report

```dart
final report = await NetworkDiagnostic.diagnose(includePorts: true);

print(report); // NetworkDiagnosticReport(type: wifi, connected: true, score: 87.5)
print(report.toMap()); // JSON encodable
```

### Benchmarks

```dart
final suite = await NetworkBenchmark.runAll(iterations: 20, warmupIterations: 3);

for (final result in suite.results) {
  print('${result.testName}: avg '
        '${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms, '
        '${result.operationsPerSecond.toStringAsFixed(1)} ops/s');
}
```

Benchmarks answer questions like *"how expensive is one `checkConnection()` call
on this device?"* — useful when deciding whether a diagnostic belongs on the
startup path.

## Testing your own code against it

Every service is injectable, so you can unit-test your integration points without
a network:

```dart
class FakeConnectivityAdapter implements ConnectivityAdapter {
  @override
  Future<List<String>> checkConnectivity() async => <String>['wifi'];

  @override
  Stream<List<String>> get onConnectivityChanged => const Stream.empty();
}

NetworkDiagnostic.configure(
  connectivity: ConnectivityService(adapter: FakeConnectivityAdapter()),
);
```

`NetworkDiagnostic.reset()` restores the built-in defaults.

## Platform support

| Platform | Status |
| --- | --- |
| Android | ✅ Supported (Kotlin native side) |
| iOS | ✅ Supported (Swift native side) |
| macOS | ✅ Supported (Swift native side) |
| Windows | ✅ Supported (C++ native side) |
| Linux | ✅ Supported (C++ native side) |
| Web | ⚠️ Partial — see [Web support](#web-support) below |

### Web support

The web build exposes the same static API. Capabilities that the browser sandbox
forbids degrade gracefully — they return `null` or an "unavailable" result
instead of throwing:

| Capability | Web | Notes |
| --- | --- | --- |
| Connectivity | ✅ | via `connectivity_plus` |
| Ping (`PingMode.tcp`) | ⚠️ | HTTPS round trip; the target must send CORS headers |
| Ping (`PingMode.icmp`) | ❌ | throws `UnsupportedError` |
| DNS (system resolver) | ✅ | via DNS-over-HTTPS |
| DNS (explicit server) | ⚠️ | needs a DoH endpoint, otherwise "unsupported" |
| Speed test | ✅ | HTTP download / upload |
| Quality score | ✅ | pure function |
| Benchmark | ✅ | pure function |
| Port check / scan | ❌ | returns "unavailable" results |
| Native details (SSID, gateway, MAC, VPN) | ❌ | `null` |

`ZeroNetworkKit.getNativeNetworkDetails()` returns `null` on the web and
`ZeroNetworkKit.getPlatformVersion()` returns `Web`. Call
`NetworkCapabilities.current()` to discover the supported set at runtime.

## Documentation

- [API.md](API.md) — complete usage guide: every public API with copy-paste
  examples, parameter defaults, model reference and common pitfalls.
- [AGENTS.md](AGENTS.md) — engineering contract: architecture, conventions and the
  new-feature checklist.
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to set up and submit changes.
- [CHANGELOG.md](CHANGELOG.md) — release history.

## License

[MPL-2.0](LICENSE) © Zero Labs

Third-party dependency, trademark and endorsement notices live in
[NOTICE](NOTICE).
