# Installation / 安装

## From pub.dev (Recommended) / 从 pub.dev 安装（推荐）

Add the following to your `pubspec.yaml`:

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_network_kit: ^__ZNK_VERSION__
```

Then run:

然后运行：

```bash
flutter pub get
```

## From GitHub / 从 GitHub 安装

Alternatively, install from GitHub:

或者从 GitHub 安装：

```yaml
dependencies:
  zero_network_kit:
    git:
      url: https://github.com/zero-labsco/zero_network_kit.git
      ref: release/v__ZNK_VERSION__
```

## Platform Setup / 平台配置

### Android

The plugin manifest already declares `INTERNET`, `ACCESS_NETWORK_STATE` and
`ACCESS_WIFI_STATE`. Reading the Wi-Fi **SSID** additionally requires the
location permission (`ACCESS_FINE_LOCATION`) on Android 8.1+, otherwise the
snapshot reports `ssid: null`.

插件清单已声明 `INTERNET`、`ACCESS_NETWORK_STATE` 与 `ACCESS_WIFI_STATE`。读取 Wi-Fi
**SSID** 还需在 Android 8.1+ 申请定位权限（`ACCESS_FINE_LOCATION`），否则快照中
`ssid` 为 `null`。

### iOS

No additional configuration needed. Reading the Wi-Fi **SSID** additionally
requires the *Access WiFi Information* capability plus location authorisation.

无需额外配置。读取 Wi-Fi **SSID** 还需开启 *Access WiFi Information* 能力并授权定位。

### macOS / Windows / Linux

The plugin is declared on all three desktop platforms. On desktop, native
details such as SSID / RSSI are **always `null`** (tier A). Windows additionally
provides gateway / MAC / DNS / VPN through `GetAdaptersAddresses`; macOS and
Linux report only the Dart-side IP/IPv6. See
[Platform Support](Platform-Support) for the full matrix.

插件已在三个桌面平台声明。桌面上 SSID / 信号强度等原生详情**恒为 `null`**（A 档）。
Windows 额外通过 `GetAdaptersAddresses` 提供网关 / MAC / DNS / VPN；macOS 与 Linux
仅提供 Dart 侧的 IP/IPv6。完整矩阵见[平台支持](Platform-Support)。

## Import / 导入

```dart
import 'package:zero_network_kit/zero_network_kit.dart';
```

## Requirements / 环境要求

| Requirement | Version |
|-------------|---------|
| Flutter | >= 3.3.0 |
| Dart SDK | >= 3.11.0 < 4.0.0 |

## Next Steps / 下一步

- [Getting Started](Getting-Started) — Quick start guide / 快速开始
- [Usage](Usage) — Full usage guide / 完整使用指南
