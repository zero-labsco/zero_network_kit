# Usage / 用法

## Which API do I need? / 该用哪个 API？

| I want to know… | Call |
| --- | --- |
| Am I online, and over what transport? | `NetworkDiagnostic.checkConnection()` |
| React to Wi-Fi ⇄ cellular switches | `NetworkDiagnostic.onConnectivityChanged` |
| Latency, jitter, packet loss | `NetworkDiagnostic.ping()` |
| Is DNS slow or broken? | `NetworkDiagnostic.resolve()` |
| Is `host:port` reachable? | `NetworkDiagnostic.checkPort()` |
| Which of these ports are open? | `NetworkDiagnostic.scanPorts()` |
| How fast is down/up? | `NetworkDiagnostic.runSpeedTest()` |
| One number for “good or bad” | `NetworkDiagnostic.evaluateQuality()` |
| Everything at once, as a report | `NetworkDiagnostic.diagnose()` |
| Is the diagnostics API itself expensive? | `NetworkBenchmark.runAll()` |
| Native version / SSID / gateway / MAC | `ZeroNetworkKit.getPlatformVersion()`, `getNativeNetworkDetails()` |

## Global configuration / 全局配置

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
| `pingHost` | `'1.1.1.1'` | Default ping / port-scan target |
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
| `speedTestTimeout` | `30s` | Per-request timeout |
| `speedTestMaxDuration` | `10s` | Sampling window per phase |
| `portCheckTimeout` | `3s` | Timeout of one port check |
| `probePorts` | `[80, 443]` | Ports used by `scanPorts()` by default |
| `qualityTargets` | `const QualityTargets()` | Ideal values for scoring |

> The default speed-test endpoints are Cloudflare's public service. Swap them for
> your own before shipping production traffic.
> 默认测速端点是 Cloudflare 的公共服务，正式项目请替换为自建端点。

### Quality targets / 质量评分理想值

```dart
const NetworkDiagnosticConfig(
  qualityTargets: QualityTargets(
    excellentLatency: 30,     // ms
    acceptableLatency: 150,   // ms
    excellentJitter: 5,       // ms
    acceptableJitter: 40,     // ms
    acceptablePacketLoss: 5,   // %
    excellentDownload: 50,     // Mbps
    acceptableDownload: 5,     // Mbps
    excellentUpload: 20,       // Mbps
    acceptableUpload: 2,       // Mbps
    excellentDns: 30,          // ms
    acceptableDns: 200,        // ms
  ),
);
```

## JSON serialisation / 序列化

Every result object implements `toMap()` and is JSON encodable:

每个结果对象都实现了 `toMap()`，可直接 JSON 序列化：

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

## Dependency injection & tests / 注入与测试

Every service accepts its collaborators, so your integration points are
unit-testable without touching the network.

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

也可以直接替换单个服务：

```dart
NetworkDiagnostic.pingService = MyFakePingService();
NetworkDiagnostic.dnsService = MyFakeDnsService();
```

> For advanced service classes, the DNS wire codec and low-level APIs, import
> `package:zero_network_kit/advanced.dart`.
> 进阶的服务类、DNS 报文编解码器等底层 API 请通过
> `package:zero_network_kit/advanced.dart` 引入。
