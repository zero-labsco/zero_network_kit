# zero_network_kit

<div align="center">

[English](README.md) &nbsp;|&nbsp; **简体中文**

</div>

一个 Flutter **网络诊断**插件：连通性检测、延迟探测、DNS 解析、端口检测、带宽
测速、质量评分与微基准测试，支持 Android、iOS、macOS、Windows、Linux 与 Web（部分支持）。

[![pub version](https://img.shields.io/pub/v/zero_network_kit.svg)](https://pub.dev/packages/zero_network_kit)
[![pub points](https://img.shields.io/pub/points/zero_network_kit.svg)](https://pub.dev/packages/zero_network_kit/score)
[![CI](https://github.com/zero-labsco/zero_network_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_network_kit/actions/workflows/ci.yml)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://github.com/zero-labsco/zero_network_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-green.svg)](https://pub.dev/packages/zero_network_kit)
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 推荐升级：** `1.0.3` 让包具备 WASM 兼容性——Web 构建不再引入 `connectivity_plus` 仅限 Linux 的 `nm` 依赖，因此 `flutter build web --wasm` 与 pub.dev 的平台评分（20/20）均可通过。建议升级到 `^1.0.3`。

🌐 **[官方网站](https://www.zerolabsco.com/)** &nbsp;·&nbsp; 📦 **[在 pub.dev 查看](https://pub.dev/packages/zero_network_kit)** &nbsp;·&nbsp; 🔗 **[查看 GitHub 仓库](https://github.com/zero-labsco/zero_network_kit)**

---

## 目录

- [能力一览](#能力一览)
- [引入](#引入)
  - [Android 权限](#android-权限)
- [用法](#用法)
  - [连通性](#连通性)
  - [延迟探测](#延迟探测)
  - [DNS 解析](#dns-解析)
  - [网速测试](#网速测试)
  - [端口检测](#端口检测)
  - [质量评分](#质量评分)
  - [汇总报告](#汇总报告)
  - [基准测试](#基准测试)
- [在你自己的代码里做测试](#在你自己的代码里做测试)
- [平台支持](#平台支持)
- [文档](#文档)
- [许可证](#许可证)

---

## 能力一览

| 能力 | API | 说明 |
| --- | --- | --- |
| 连通性 | `NetworkDiagnostic.checkConnection()` | 传输类型、IPv4/IPv6、网关、SSID、信号强度、MAC、VPN |
| 连通性监听 | `NetworkDiagnostic.onConnectivityChanged` | 每次变化都重新采集并推送快照 |
| 延迟 | `NetworkDiagnostic.ping()` | 全平台 TCP 握手往返；桌面端可用系统 ICMP |
| DNS | `NetworkDiagnostic.resolve()` | `system` 解析器 + 直连指定服务器的原始 UDP 查询 |
| 带宽 | `NetworkDiagnostic.runSpeedTest()` | 下载/上传速率，带进度回调 |
| 端口 | `NetworkDiagnostic.checkPort()` / `scanPorts()` | 限定并发的 TCP 可达性检测 |
| 质量评分 | `NetworkDiagnostic.evaluateQuality()` | 0–100 加权得分 + 等级 + 优化建议 |
| 汇总报告 | `NetworkDiagnostic.diagnose()` | 一次性聚合全部探测结果 |
| 能力探测 | `NetworkDiagnostic.capabilities` | 先查询后调用，按平台隐藏不支持的卡片（如桌面 SSID） |
| 基准测试 | `NetworkBenchmark.runAll()` | 测量诊断 API 自身的耗时 |

设计原则：

- **单元测试不依赖网络** —— 每个服务都支持注入协作对象
  （`ConnectivityAdapter`、`http.Client`、`PingService` 等）。
- **无隐藏状态** —— 结果都是不可变值对象，并带 `toMap()`。
- **优雅降级** —— 缺权限或子服务不可用不会让公共 API 抛异常，对应字段保持
  `null`。

## 引入

```yaml
dependencies:
  zero_network_kit: ^1.0.3
```

### Android 权限

插件自带的 manifest 已声明 `INTERNET`、`ACCESS_NETWORK_STATE`、
`ACCESS_WIFI_STATE`。若要读取 Wi-Fi **SSID**，Android 8.1+ 还需定位权限
（`ACCESS_FINE_LOCATION`），iOS 需要 *Access WiFi Information* 权限与定位授权。
未授权时快照中的 `ssid` 为 `null`，不会报错。

## 用法

下面覆盖常用路径；**全部方法、参数默认值与结果字段**请见
**[接口使用指南](API_zh.md)**。

```dart
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  // 可选：全局定制一次默认参数。
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(
      pingHost: '1.1.1.1',
      dnsServers: <String>['1.1.1.1', '8.8.8.8'],
    ),
  );
  runApp(const MyApp());
}
```

### 连通性

```dart
final info = await NetworkDiagnostic.checkConnection(probeReachability: true);

print('${info.type.label} · ${info.ipAddress} · ${info.signalStrength} dBm');
print('网关=${info.gateway} VPN=${info.isVpn} 可达=${info.isReachable}');

await for (final change in NetworkDiagnostic.onConnectivityChanged) {
  print('当前网络：${change.type.id}');
}
```

> **只要连通性？** 无需 `init()`，也不需其它 API —— `checkConnection()` 与
> `onConnectivityChanged` 开箱即用。完整的最小示例见 [API_zh.md](API_zh.md)
> 连通性章节的「仅连通性：最小示例」。

### 延迟探测

```dart
final result = await NetworkDiagnostic.ping(host: '1.1.1.1', count: 5);

print('收到 ${result.received}/${result.sent}，'
      '丢包 ${result.packetLoss.toStringAsFixed(1)}%，'
      '平均 ${result.averageTime.toStringAsFixed(1)} ms，'
      '抖动 ${result.jitter.toStringAsFixed(2)} ms');
```

桌面端可切换到系统 ICMP：

```dart
await NetworkDiagnostic.ping(host: '1.1.1.1', mode: PingMode.icmp);
```

### DNS 解析

```dart
final results = await NetworkDiagnostic.resolve(
  domain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8'],
  includeSystemResolver: true,
);

for (final r in results) {
  print('${r.server}: ${r.isSuccess ? r.resolvedIps.join(", ") : r.errorMessage}'
        '（${r.responseTimeMs.toStringAsFixed(1)} ms）');
}
```

### 网速测试

```dart
final speed = await NetworkDiagnostic.runSpeedTest(
  onProgress: (progress) => print(
    '${progress.phase.name}: ${progress.speedMbps.toStringAsFixed(1)} Mbps',
  ),
);

print('下载 ${speed.downloadSpeed.toStringAsFixed(2)} Mbps  '
      '上传 ${speed.uploadSpeed.toStringAsFixed(2)} Mbps');
```

下载与上传阶段会产生可观流量，默认使用 Cloudflare 公共测速端点；可通过
`downloadUrl` / `uploadUrl` 换成自建端点。

### 端口检测

```dart
if (await NetworkDiagnostic.isPortOpen(host: 'example.com', port: 443)) {
  print('HTTPS 可达');
}

final scan = await NetworkDiagnostic.scanPorts(
  host: 'example.com',
  ports: const <int>[22, 80, 443, 8080],
  concurrency: 8,
);
```

### 质量评分

```dart
final score = await NetworkDiagnostic.evaluateQuality(includeSpeedTest: false);

print('${score.score}/100（${score.level.label}）');
for (final suggestion in score.suggestions) {
  print('• $suggestion');
}
```

综合得分为「当前可用的指标」的加权平均：

| 指标 | 权重 | 来源 |
| --- | --- | --- |
| `latency` | 0.25 | `PingResult.averageTime` |
| `jitter` | 0.10 | `PingResult.jitter` |
| `packetLoss` | 0.15 | `PingResult.packetLoss` |
| `download` | 0.25 | `SpeedTestResult.downloadSpeed` |
| `upload` | 0.15 | `SpeedTestResult.uploadSpeed` |
| `dns` | 0.10 | 成功的 `DnsTestResult.responseTimeMs` 均值 |
| `signalStrength` | 0.10 | `NetworkConnectionInfo.signalStrength` |

可通过 `NetworkDiagnosticConfig(qualityTargets: ...)` 调整理想值。

### 汇总报告

```dart
final report = await NetworkDiagnostic.diagnose(includePorts: true);

print(report); // NetworkDiagnosticReport(type: wifi, connected: true, score: 87.5)
print(report.toMap()); // 可直接 JSON 编码
```

### 基准测试

```dart
final suite = await NetworkBenchmark.runAll(iterations: 20, warmupIterations: 3);

for (final result in suite.results) {
  print('${result.testName}: 平均 '
        '${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms，'
        '${result.operationsPerSecond.toStringAsFixed(1)} 次/秒');
}
```

基准测试回答的是「在这台设备上调用一次 `checkConnection()` 有多贵」这类问题，
适合用来判断某项诊断能否放在启动路径上。

## 在你自己的代码里做测试

所有服务都可注入，因此可以完全脱离网络做单元测试：

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

调用 `NetworkDiagnostic.reset()` 可恢复内置默认实现。

## 平台支持

| 平台 | 状态 |
| --- | --- |
| Android | ✅ 支持（Kotlin 原生实现） |
| iOS | ✅ 支持（Swift 原生实现） |
| macOS | ✅ 支持（Swift 原生实现） |
| Windows | ✅ 支持（C++ 原生实现） |
| Linux | ✅ 支持（C++ 原生实现） |
| Web | ⚠️ 部分支持——详见下方 [Web 支持](#web-支持) |

### Web 支持

Web 构建提供同样的静态 API；浏览器沙箱禁止的能力会优雅降级（返回 `null`
或“不可用”结果，而不是抛异常）：

| 能力 | Web | 说明 |
| --- | --- | --- |
| 连通性检测 | ✅ | 通过 `connectivity_plus` |
| Ping（`PingMode.tcp`） | ⚠️ | 以 HTTPS 往返耗时度量，目标主机需下发 CORS 头 |
| Ping（`PingMode.icmp`） | ❌ | 抛出 `UnsupportedError` |
| DNS（系统解析器） | ✅ | 通过 DNS-over-HTTPS |
| DNS（指定服务器） | ⚠️ | 需要 DoH 端点，否则返回“不支持” |
| 带宽测速 | ✅ | HTTP 下载 / 上传 |
| 质量评分 | ✅ | 纯函数 |
| 微基准 | ✅ | 纯函数 |
| 端口检测 / 扫描 | ❌ | 返回“不可用”结果 |
| 原生详情（SSID、网关、MAC、VPN） | ❌ | 返回 `null` |

Web 上 `ZeroNetworkKit.getNativeNetworkDetails()` 返回 `null`，
`ZeroNetworkKit.getPlatformVersion()` 返回 `Web`；运行时可用
`NetworkCapabilities.current()` 查询当前平台支持的能力集合。

## 文档

- [API_zh.md](API_zh.md) —— 接口使用指南：全部公开 API 的可复制示例、参数
  默认值、模型字段速查与常见陷阱。
- [AGENTS.md](AGENTS.md) —— 开发规范：架构、约定与新增功能清单。
- [CONTRIBUTING.md](CONTRIBUTING.md) —— 环境准备与提交改动流程。
- [CHANGELOG.md](CHANGELOG.md) —— 版本历史。

## 许可证

[MPL-2.0](LICENSE) © Zero Labs

第三方依赖、商标与免责声明见 [NOTICE](NOTICE)。
