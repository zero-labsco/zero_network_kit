# Getting Started / 快速开始

## Quick Start / 快速开始

Import the package and start diagnosing — no `init()` required:

导入包即可开始诊断，无需 `init()`：

```dart
import 'package:flutter/material.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  // Optional: apply your own global defaults once.
  // 可选：全局定制一次默认参数。
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(pingHost: '1.1.1.1'),
  );
  runApp(const MyApp());
}
```

If you only need connectivity, you don't even need `init()`:

如果只需要连通性，连 `init()` 都不需要：

```dart
final connection = await NetworkDiagnostic.checkConnection();
print('${connection.type.label} · ${connection.ipAddress}');
```

## What you get / 你能得到什么

Every method is a static, non-blocking call on the `NetworkDiagnostic` facade.
The plugin is pure Dart under the hood, so it is fully injectable and testable
without touching the network.

每个方法都是 `NetworkDiagnostic` 门面上的静态、非阻塞调用。插件内核是纯 Dart，
因此完全可注入、可脱离网络做测试。

| Need | Call |
| --- | --- |
| Am I online, on what transport? | `NetworkDiagnostic.checkConnection()` |
| React to Wi-Fi ⇄ cellular switches | `NetworkDiagnostic.onConnectivityChanged` |
| Latency, jitter, packet loss | `NetworkDiagnostic.ping()` |
| Is DNS slow or broken? | `NetworkDiagnostic.resolve()` |
| Is `host:port` reachable? | `NetworkDiagnostic.checkPort()` / `isPortOpen()` |
| How fast is down/up? | `NetworkDiagnostic.runSpeedTest()` |
| One number for "good or bad" | `NetworkDiagnostic.evaluateQuality()` |
| Everything at once | `NetworkDiagnostic.diagnose()` |
| Native version / SSID / gateway / MAC | `ZeroNetworkKit.getNativeNetworkDetails()` |

See [Which API do I need?](Usage#which-api-do-i-need) for the full map.

## Lifecycle / 生命周期

```dart
ZeroNetworkKit.isInitialized; // false until init() runs
ZeroNetworkKit.config;        // the effective NetworkDiagnosticConfig

await ZeroNetworkKit.dispose(); // releases the HTTP client the plugin owns
```

`dispose()` only closes the HTTP client the plugin created itself. An
`http.Client` you injected stays open — close it yourself.

`dispose()` 只会关闭插件自己创建的 HTTP 客户端；你注入的 `http.Client` 不会被关闭。

## Next Steps / 下一步

- [Installation](Installation) — Detailed installation methods / 详细安装方式
- [Usage](Usage) — Global config & dependency injection / 全局配置与依赖注入
- [Platform Support](Platform-Support) — Capability matrix / 能力矩阵
