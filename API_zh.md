# 接口使用指南 / API Guide

`zero_network_kit` **全部公开功能**的使用示例，每个代码块都可以直接复制运行。

[English](API.md) | **简体中文**

> 注意：本插件的 `NetworkType` 只有 `label` 与 `id`，**没有** `displayName`。
> 请写 `connection.type.label`，而不是 `connection.type.displayName`。

---

## 目录

| # | 能力 | API |
| --- | --- | --- |
| 0 | [引入与初始化](#0-引入与初始化) | `ZeroNetworkKit.init()` |
| 1 | [该用哪个 API？](#1-该用哪个-api) | — |
| 2 | [全局配置](#2-全局配置) | `NetworkDiagnosticConfig` |
| 3 | [连通性](#3-连通性) | `checkConnection()` |
| 4 | [连通性监听](#4-连通性监听) | `onConnectivityChanged` |
| 5 | [延迟探测](#5-延迟探测) | `ping()` |
| 6 | [DNS 解析](#6-dns-解析) | `resolve()` |
| 7 | [端口检测](#7-端口检测) | `checkPort()` / `scanPorts()` |
| 8 | [测速](#8-测速) | `runSpeedTest()` |
| 9 | [质量评分](#9-质量评分) | `evaluateQuality()` |
| 10 | [汇总报告](#10-汇总报告) | `diagnose()` |
| 11 | [微基准测试](#11-微基准测试) | `NetworkBenchmark.runAll()` |
| 12 | [原生平台信息](#12-原生平台信息) | `getPlatformVersion()` |
| 13 | [序列化](#13-序列化) | `toMap()` |
| 14 | [注入与测试](#14-注入与测试) | `configure()` |
| 15 | [模型字段速查](#15-模型字段速查) | — |
| 16 | [常见陷阱](#16-常见陷阱) | — |

---

## 0. 引入与初始化

```dart
import 'package:zero_network_kit/zero_network_kit.dart';
```

一个 import 就能拿到全部能力。初始化是**可选的**——不调用也能直接用（走内置默认值）。

```dart
void main() {
  // 可选：全局定制一次默认参数。
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(pingHost: '1.1.1.1'),
  );
  runApp(const MyApp());
}
```

应用退出时释放插件自己持有的 HTTP 客户端：

```dart
await ZeroNetworkKit.dispose();
```

查看当前状态：

```dart
ZeroNetworkKit.isInitialized; // 未调用 init() 时为 false
ZeroNetworkKit.config;        // 当前生效的 NetworkDiagnosticConfig
```

## 1. 该用哪个 API？

| 我想知道…… | 调用 |
| --- | --- |
| 我在线吗？走的什么链路？ | `NetworkDiagnostic.checkConnection()` |
| 监听 Wi-Fi ⇄ 蜂窝 切换 | `NetworkDiagnostic.onConnectivityChanged` |
| 延迟、抖动、丢包 | `NetworkDiagnostic.ping()` |
| DNS 慢还是坏了？ | `NetworkDiagnostic.resolve()` |
| `host:port` 通不通？ | `NetworkDiagnostic.checkPort()` |
| 这批端口哪些开着？ | `NetworkDiagnostic.scanPorts()` |
| 上下行有多快？ | `NetworkDiagnostic.runSpeedTest()` |
| 一句话结论「好还是不好」 | `NetworkDiagnostic.evaluateQuality()` |
| 一次跑完全部并汇总 | `NetworkDiagnostic.diagnose()` |
| 这套诊断 API 本身贵不贵？ | `NetworkBenchmark.runAll()` |
| 原生版本 / SSID / 网关 / MAC | `ZeroNetworkKit.getPlatformVersion()`、`getNativeNetworkDetails()` |

## 2. 全局配置

`NetworkDiagnosticConfig` 集中了全部默认参数，只需覆盖你关心的字段，其余保持默认。

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

| 字段 | 默认值 | 含义 |
| --- | --- | --- |
| `pingHost` | `'1.1.1.1'` | 默认 Ping / 端口扫描目标 |
| `pingPort` | `443` | TCP Ping 使用的端口 |
| `pingCount` | `4` | 每次 Ping 的探测次数 |
| `pingTimeout` | `3s` | 单次探测超时 |
| `pingInterval` | `200ms` | 两次探测之间的间隔 |
| `dnsDomain` | `'www.google.com'` | 默认 DNS 测试域名 |
| `dnsServers` | `['1.1.1.1', '8.8.8.8', '114.114.114.114']` | 默认查询的 DNS 服务器 |
| `dnsTimeout` | `5s` | 单台服务器查询超时 |
| `downloadUrl` | Cloudflare `__down?bytes=25000000` | 下载测速端点 |
| `uploadUrl` | Cloudflare `__up` | 上传测速端点 |
| `uploadPayloadBytes` | `1048576`（1 MiB） | 上传负载大小 |
| `speedTestTimeout` | `30s` | 单请求超时 |
| `speedTestMaxDuration` | `10s` | 每个阶段的采样时长 |
| `portCheckTimeout` | `3s` | 单端口检测超时 |
| `probePorts` | `[80, 443]` | `scanPorts()` 默认扫描的端口 |
| `qualityTargets` | `const QualityTargets()` | 质量评分理想值 |

默认测速端点是 Cloudflare 的公共服务，正式项目请替换为自建端点。

### 质量评分理想值

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

## 3. 连通性

```dart
final connection = await NetworkDiagnostic.checkConnection();

print('类型      : ${connection.type.label}'); // Wi-Fi / Mobile / Ethernet …
print('已连接    : ${connection.isConnected}');
print('IPv4      : ${connection.ipAddress}');
print('IPv6      : ${connection.ipv6Address}');
print('网关      : ${connection.gateway}');
print('SSID      : ${connection.ssid}');
print('信号      : ${connection.signalStrength} dBm');
print('MAC       : ${connection.macAddress}');
print('VPN       : ${connection.isVpn}');
print('采样时间  : ${connection.timestamp}');
```

参数：

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `includeNativeDetails` | `true` | 是否走原生通道读取 SSID / 网关 / MAC / VPN |
| `probeReachability` | `false` | 是否额外发一次真实请求填充 `isReachable` |
| `probeTimeout` | `3s` | 上述可达性探测的超时 |

```dart
// 跳过原生通道（最省，适合放在热路径上）。
final quick = await NetworkDiagnostic.checkConnection(
  includeNativeDetails: false,
);

// 确认「真的能上外网」，而不只是网卡亮着。
final verified = await NetworkDiagnostic.checkConnection(
  probeReachability: true,
  probeTimeout: const Duration(seconds: 5),
);

if (verified.isReachable == false) {
  print('网卡是通的，但外网不可达。');
}
```

### 仅连通性：最小示例

如果只需要「在不在線、走什么網络、IP 是多少、切换时通知」，只用第 3、4 节即可——
**无需 `init()`**，也不必调用 ping / DNS / 测速。

一次性快照（纯 Dart，无需 Widget）：

```dart
final c = await NetworkDiagnostic.checkConnection();
print('${c.type.label} · 在线=${c.isConnected} · IP=${c.ipAddress}');
```

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
            ListTile(title: const Text('类型'), trailing: Text(c.type.label)),
            ListTile(title: const Text('在线'), trailing: Text('${c.isConnected}')),
            ListTile(title: const Text('IPv4'), trailing: Text(c.ipAddress ?? '—')),
            ListTile(title: const Text('IPv6'), trailing: Text(c.ipv6Address ?? '—')),
          ],
        );
      },
    );
  }
}
```

> `ZeroNetworkKit.init()` 是可选的，仅在想覆盖默认参数时才需要；单用连通性直接走内置默认值即可。

## 4. 连通性监听

```dart
final subscription = NetworkDiagnostic.onConnectivityChanged.listen(
  (info) => print('当前网络 ${info.type.id} · ${info.ipAddress}'),
);

// 之后取消：
await subscription.cancel();
```

在 Widget 里：

```dart
StreamBuilder<NetworkConnectionInfo>(
  stream: NetworkDiagnostic.onConnectivityChanged,
  builder: (context, snapshot) {
    final info = snapshot.data;
    if (info == null) return const Text('检测中…');
    return Text('${info.type.label} · ${info.isConnected}');
  },
)
```

## 5. 延迟探测

```dart
final ping = await NetworkDiagnostic.ping(
  host: '1.1.1.1',
  count: 5,
  timeout: const Duration(seconds: 2),
  interval: const Duration(milliseconds: 200),
  port: 443,
);

print('收到     : ${ping.received}/${ping.sent}');
print('丢包     : ${ping.packetLoss.toStringAsFixed(1)} %');
print('最小/平均/最大: ${ping.minTime.toStringAsFixed(1)} / '
      '${ping.averageTime.toStringAsFixed(1)} / '
      '${ping.maxTime.toStringAsFixed(1)} ms');
print('抖动     : ${ping.jitter.toStringAsFixed(2)} ms');
print('样本     : ${ping.times}');
```

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `host` | `config.pingHost` | 目标主机 |
| `count` | `config.pingCount` | 探测次数 |
| `timeout` | `config.pingTimeout` | 单次探测超时 |
| `interval` | `config.pingInterval` | 探测间隔 |
| `port` | `config.pingPort` | `PingMode.tcp` 下探测的端口 |
| `mode` | `PingMode.tcp` | `PingMode.tcp` 或 `PingMode.icmp` |

### TCP 与 ICMP

`PingMode.tcp` 通过 TCP 握手到 `host:port` 测量往返，是 ICMP 的可移植等价物，
也是 Android / iOS 上唯一可用的方式。

```dart
// 仅桌面端可用；`ping` 命令不存在时会优雅降级。
await NetworkDiagnostic.ping(host: '1.1.1.1', count: 4, mode: PingMode.icmp);
```

至少一次收到响应时 `ping.isSuccess` 才为 `true`，读平均值前建议先判断它。

## 6. DNS 解析

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
          '（${r.responseTimeMs.toStringAsFixed(1)} ms）');
  } else {
    print('${r.server.padRight(16)} ✗ ${r.errorMessage}');
  }
}
```

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `domain` | `config.dnsDomain` | 待解析域名 |
| `dnsServers` | `config.dnsServers` | 依次/并发查询的服务器列表 |
| `timeout` | `config.dnsTimeout` | 单台服务器查询超时 |
| `concurrent` | `true` | 是否并发查询全部服务器 |
| `includeSystemResolver` | `false` | 是否追加一行 `system` |

说明：

- `server == 'system'` 的行来自系统解析器；其余是对指定 IP 的**原始 UDP 查询**，
  由内置的纯 Dart `DnsPacket` 编解码。
- `includeSystemResolver` 在门面层默认为 **`false`**，需要系统解析器时请显式传 `true`。

```dart
// 挑出最快的一台解析器。
final fastest = results
    .where((r) => r.isSuccess)
    .reduce((a, b) => a.responseTimeMs <= b.responseTimeMs ? a : b);
print('最快解析器：${fastest.server}');
```

## 7. 端口检测

```dart
// 单端口 → 布尔便捷
final open = await NetworkDiagnostic.isPortOpen(
  host: 'example.com',
  port: 443,
  timeout: const Duration(seconds: 3),
);
print(open ? 'HTTPS 可达' : 'HTTPS 不可达');
```

```dart
// 多端口 → 每条结果都带 RTT 与失败原因
final scan = await NetworkDiagnostic.scanPorts(
  host: 'example.com',
  ports: const <int>[22, 80, 443, 8080, 8443],
  concurrency: 8,
);

for (final r in scan) {
  print('${r.host}:${r.port} '
        '${r.isOpen ? "开放" : "关闭"} '
        '${r.responseTimeMs.toStringAsFixed(1)} ms '
        '${r.errorMessage ?? ""}');
}
```

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `ports`（`scanPorts`） | `config.probePorts`（`[80, 443]`） | 待探测端口 |
| `concurrency` | `12` | 最大并发连接数 |
| `timeout` | `config.portCheckTimeout` | 单端口超时 |

> `checkPort()` 返回 **`PortCheckResult`**（含 `isOpen`、`responseTimeMs`、
> `errorMessage`）；单端口布尔诉求请用 `isPortOpen()`。需要 RTT 或失败原因时
> 可直接调用 `checkPort()`，或给 `scanPorts(host: 'example.com', ports: [443])` 取单条结果。

## 8. 测速

```dart
final speed = await NetworkDiagnostic.runSpeedTest(
  includeUpload: true,
  includePing: true,
  onProgress: (progress) {
    print('${progress.phase.name}: '
          '${progress.speedMbps.toStringAsFixed(1)} Mbps '
          '（${progress.bytes} 字节，${progress.elapsed.inMilliseconds} ms）');
  },
);

print('下载     : ${speed.downloadSpeed.toStringAsFixed(2)} Mbps');
print('上传     : ${speed.uploadSpeed.toStringAsFixed(2)} Mbps');
print('延迟     : ${speed.ping.toStringAsFixed(1)} ms');
print('抖动     : ${speed.jitter.toStringAsFixed(2)} ms');
print('丢包     : ${speed.packetLoss.toStringAsFixed(1)} %');
print('服务端   : ${speed.server}');
print('总耗时   : ${speed.duration.inMilliseconds} ms');
```

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `downloadUrl` / `uploadUrl` | 来自 config | 使用的端点 |
| `timeout` | `config.speedTestTimeout` | 单请求超时 |
| `maxDuration` | `config.speedTestMaxDuration` | 每阶段采样时长 |
| `uploadPayloadBytes` | `config.uploadPayloadBytes` | 上传大小 |
| `pingHost` / `pingCount` | 来自 config | 测速期间采样的延迟 |
| `includeUpload` | `true` | 是否跳过上传阶段 |
| `includePing` | `true` | 是否跳过延迟采样 |
| `onProgress` | `null` | 两个阶段中都会被反复调用 |

进度阶段依次为 `SpeedTestPhase.download` → `SpeedTestPhase.upload` →
`SpeedTestPhase.completed`。

轻量低流量版本（跳过上传与延迟）：

```dart
final quick = await NetworkDiagnostic.runSpeedTest(
  includeUpload: false,
  includePing: false,
  maxDuration: const Duration(seconds: 5),
);
```

## 9. 质量评分

```dart
final quality = await NetworkDiagnostic.evaluateQuality(
  includePing: true,
  includeDns: true,
  includeSpeedTest: true,
  includeUpload: true,
);

print('${quality.score.toStringAsFixed(1)}/100 —— ${quality.level.label}');
quality.metrics.forEach((metric, value) {
  print('  $metric = ${value.toStringAsFixed(2)}');
});
for (final suggestion in quality.suggestions) {
  print('• $suggestion');
}
```

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `includePing` | `true` | 采样延迟 / 抖动 / 丢包 |
| `includeDns` | `true` | 采样 DNS 耗时 |
| `includeSpeedTest` | `true` | 采样上下行（流量较大） |
| `includeUpload` | `true` | 是否计入上传指标 |
| `pingHost` / `pingCount` | 来自 config | 延迟目标 |
| `dnsDomain` / `dnsServers` | 来自 config | DNS 目标 |
| `downloadUrl` / `uploadUrl` | 来自 config | 带宽端点 |

不消耗流量的轻量版本：

```dart
final quality = await NetworkDiagnostic.evaluateQuality(includeSpeedTest: false);
```

要调整评分理想值，只能通过全局配置（`evaluateQuality` 没有单次调用的目标参数）：

```dart
ZeroNetworkKit.init(
  config: const NetworkDiagnosticConfig(
    qualityTargets: QualityTargets(excellentLatency: 20, acceptableLatency: 100),
  ),
);
```

如果指标已经在手，可以完全不走网络，直接用纯函数打分：

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

等级阈值：`≥90` 极佳 · `≥75` 良好 · `≥60` 一般 · `≥40` 较差 · 其余为极差
（见 `NetworkQualityLevel.fromScore`）。

权重分配（只对「可用的指标」加权平均）：

| `quality.metrics` 中的键 | 权重 | 来源 |
| --- | --- | --- |
| `latency` | 0.25 | `PingResult.averageTime` |
| `jitter` | 0.10 | `PingResult.jitter` |
| `packetLoss` | 0.15 | `PingResult.packetLoss` |
| `download` | 0.25 | `SpeedTestResult.downloadSpeed` |
| `upload` | 0.15 | `SpeedTestResult.uploadSpeed` |
| `dns` | 0.10 | 成功的 `DnsTestResult.responseTimeMs` 均值 |
| `signalStrength` | 0.10 | `NetworkConnectionInfo.signalStrength` |

## 10. 汇总报告

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

print(report);                                  // 一行摘要
print(report.connection.type.label);
print(report.ping?.averageTime);
print(report.dnsResults.length);
print(report.portResults.where((p) => p.isOpen).length);
print(report.speedTest?.downloadSpeed);
print(report.quality.level.label);
```

`includePorts` 默认是 `false`，默认调用不会扫端口。任何子项失败都**不会**中断整体
流程，对应字段保持空。

## 11. 微基准测试

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
        '平均 ${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms '
        '± ${(result.standardDeviation.inMicroseconds / 1000).toStringAsFixed(2)} ms '
        '${result.operationsPerSecond.toStringAsFixed(1)} 次/秒 '
        '失败=${result.failures}');
}

// 按名称取单项：
print(suite['ping']?.averageDuration);
print(suite.totalDuration);
```

单项基准：

```dart
await NetworkBenchmark.benchmarkConnection(iterations: 20);
await NetworkBenchmark.benchmarkPing(iterations: 20, host: '1.1.1.1');
await NetworkBenchmark.benchmarkDns(iterations: 20, domain: 'example.com');
await NetworkBenchmark.benchmarkPortCheck(iterations: 20, port: 443);
await NetworkBenchmark.benchmarkPlatformChannel(iterations: 20);
```

用它来判断某项诊断能否放在启动路径上。

## 12. 原生平台信息

```dart
final version = await ZeroNetworkKit.getPlatformVersion();
print(version); // 例如 'Android 14' / 'iOS 18.0'

final details = await ZeroNetworkKit.getNativeNetworkDetails();
if (details != null) {
  print(details); // SSID、BSSID、网关、MAC、VPN 标志、RSSI 等
}
```

`NetworkDiagnostic` 上也有同名便捷方法：

```dart
await NetworkDiagnostic.getPlatformVersion();
await NetworkDiagnostic.getNativeNetworkDetails();
```

平台没有该数据或缺少权限时返回 `null`（或部分字段缺失的 Map），**不会抛异常**。

## 13. 序列化

所有结果对象都实现了 `toMap()`，可直接 JSON 编码：

```dart
import 'dart:convert';

final report = await NetworkDiagnostic.diagnose(includeSpeedTest: false);
final json = jsonEncode(report.toMap());
print(json);

// 连接快照可反序列化。
final decoded = NetworkConnectionInfo.fromMap(jsonDecode(jsonEncode(
  report.connection.toMap(),
)) as Map<Object?, Object?>);
```

| 类型 | 序列化方式 |
| --- | --- |
| `NetworkConnectionInfo` | `toMap()` + `fromMap()` |
| `PingResult` | `toMap()` |
| `DnsTestResult` | `toMap()` |
| `PortCheckResult` | `toMap()` |
| `SpeedTestResult` | `toMap()` |
| `NetworkQualityScore` | `toMap()` |
| `NetworkDiagnosticReport` | `toMap()` |
| `BenchmarkResult` / `BenchmarkSuiteResult` | `toMap()` |

## 14. 注入与测试

每个服务都支持注入协作对象，集成点可以完全脱离网络做单元测试：

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

// 用完恢复默认实现。
NetworkDiagnostic.reset();
```

也可以直接替换单个服务：

```dart
NetworkDiagnostic.pingService = MyFakePingService();
NetworkDiagnostic.dnsService = MyFakeDnsService();
```

## 15. 模型字段速查

### `NetworkType`

| 成员 | 说明 |
| --- | --- |
| 枚举值 | `none`、`wifi`、`mobile`、`ethernet`、`vpn`、`bluetooth`、`other` |
| `label` | 人类可读名称：`'Wi-Fi'`、`'Mobile'`…… |
| `id` | 稳定的英文标识（即 `name`），适合持久化 |
| `isConnected` | 除 `none` 外均为 `true` |
| `NetworkType.fromRaw(Object?)` | 解析平台返回的原始字符串 |

### `NetworkConnectionInfo`

`isConnected`、`type`、`ssid`、`signalStrength`（dBm）、`ipAddress`、
`ipv6Address`、`gateway`、`macAddress`、`isVpn`、`isReachable`、`timestamp`，
以及 `copyWith({bool? isReachable})`。

### `PingResult`

字段 `host`、`port`、`mode`、`sent`、`received`、`times`、`timestamp`；
派生 `lost`、`packetLoss`（%）、`minTime`、`maxTime`、`averageTime`、
`jitter`、`isSuccess`。

### `DnsTestResult`

字段 `server`、`domain`、`isSuccess`、`responseTime`、`resolvedIps`、
`errorMessage`、`timestamp`；派生 `responseTimeMs`、`primaryAddress`。

### `PortCheckResult`

字段 `host`、`port`、`isOpen`、`responseTime`、`errorMessage`、`timestamp`；
派生 `responseTimeMs`。

### `SpeedTestResult`

字段 `downloadSpeed`、`uploadSpeed`（Mbps）、`ping`（ms）、`jitter`（ms）、
`packetLoss`（%）、`downloadedBytes`、`uploadedBytes`、`downloadDuration`、
`uploadDuration`、`server`、`timestamp`；派生 `duration`；静态方法
`SpeedTestResult.mbpsFromBytes(bytes, elapsed)`。

### `SpeedTestProgress` / `SpeedTestPhase`

`phase`（`download`、`upload`、`completed`）、`bytes`、`elapsed`、`speedMbps`。

### `NetworkQualityScore` / `NetworkQualityLevel`

`score`（0–100）、`level`、`metrics`（`Map<String, double>`）、`suggestions`、
`timestamp`；`NetworkQualityLevel.fromScore(double)`、`level.label`。

### `NetworkDiagnosticReport`

`connection`、`ping`、`dnsResults`、`portResults`、`speedTest`、`quality`、
`timestamp`。

### `BenchmarkResult` / `BenchmarkSuiteResult`

`BenchmarkResult`：`testName`、`iterations`、`totalDuration`、
`averageDuration`、`minDuration`、`maxDuration`、`standardDeviation`、
`operationsPerSecond`、`failures`、`timestamp`。
`BenchmarkSuiteResult`：`suiteName`、`results`、`totalDuration`、`timestamp`，
以及 `suite['名称']`。
另有构造辅助 `BenchmarkResult.fromSamples(...)`。

## 16. 常见陷阱

1. **是 `type.label`，不是 `displayName`。** `NetworkType` 只暴露 `label` / `id`。
2. **`checkPort()` 返回 `bool`。** 需要 RTT 或失败原因时用
   `scanPorts(..., ports: [端口])`。
3. **`includeSystemResolver` 默认 `false`。** 需要 `system` 那一行时要显式传
   `true`。
4. **TCP Ping 需要有端口在监听。** 用 `port: 443` 探测一台不开放 TCP/443 的主机
   会失败——那是「被过滤」，不是「离线」。桌面端可用 `mode: PingMode.icmp` 更接近
   真实 ICMP。
5. **`PingMode.icmp` 仅桌面端可用**，且 `ping` 命令不存在时会静默降级。
6. **测速会产生真实流量**（默认约 25 MB 下载）。在计费网络上请先征得用户同意。
7. **缺权限是降级，不是抛异常。** 缺定位权限时 `ssid == null`，其余字段照常返回。
8. **`diagnose()` 的 `includePorts` 默认 `false`。**
9. **`init()` 可选，但 `dispose()` 只关闭插件自己创建的客户端**——你注入的
   `httpClient` 不会被关闭，需要自行处理。

---

[English](API.md) · [README](README_zh.md) · [CHANGELOG](CHANGELOG.md) · [MPL-2.0](LICENSE)
