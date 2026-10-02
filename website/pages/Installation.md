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
`ACCESS_WIFI_STATE` — everything the connectivity, ping, DNS, port and speed
probes need.

Reading the Wi-Fi **SSID / BSSID** needs a `dangerous`-level permission, so the
plugin deliberately does **not** declare it: a library `<uses-permission>` is
merged into every host app, which would force the permission — and the Google
Play data-safety declaration — onto integrators that never read an SSID. Opt in
from your **host app** (`android/app/src/main/AndroidManifest.xml`) instead:

```xml
<!-- Android 13+: NEARBY_WIFI_DEVICES replaces the location permission.
     Older devices ignore the unknown permission. -->
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
    android:usesPermissionFlags="neverForLocation" />

<!-- Android 8.1 – 12 still needs the location permission. -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="32" />
```

Request the grant at runtime too (Android 6+). Without it `getNetworkDetails()`
does **not** throw — it simply leaves `ssid` / `bssid` empty.

插件清单已声明 `INTERNET`、`ACCESS_NETWORK_STATE` 与 `ACCESS_WIFI_STATE`——连通性、
延迟、DNS、端口与测速所需的全部权限。

读取 Wi-Fi **SSID / BSSID** 需要 `dangerous` 级权限，因此插件**故意不声明**：库
manifest 中的 `<uses-permission>` 会被合并进每个宿主 App，一旦声明就会把该权限（以及
Google Play 数据安全表单中的申报义务）强加给从不读取 SSID 的集成方。请改在**宿主 App**
的 `android/app/src/main/AndroidManifest.xml` 中按需 opt-in（片段见上），并在运行时动态
申请（Android 6+）。未授权时 `getNetworkDetails()` **不会抛异常**，只把 `ssid` / `bssid`
留空。

### iOS

No configuration is required, but note what the iOS native layer returns:
`ipAddress` / `ipv6Address` are read via `getifaddrs`, `gateway` comes from the
`sysctl` routing table and `isVpn` from a tunnel interface check. Only `ssid`,
`bssid`, `signalStrength` and `macAddress` are **always `null`** — the plugin
does not request the *Access WiFi Information* capability, and iOS has returned a
constant MAC since iOS 7.

无需额外配置，但请注意 iOS 原生层的实际返回：`ipAddress` / `ipv6Address` 通过
`getifaddrs` 读取，`gateway` 取自 `sysctl` 路由表，`isVpn` 来自隧道网卡判断；只有
`ssid`、`bssid`、`signalStrength` 与 `macAddress` **恒为 `null`** —— 插件未申请
*Access WiFi Information* 能力，且 iOS 7 起 MAC 返回固定值。

### macOS / Windows / Linux

The plugin is declared on all three desktop platforms. SSID / BSSID / RSSI are
**always `null`** on desktop. **Windows** additionally provides
`ipAddress` / `ipv6Address` / `gateway` / `macAddress` / `isVpn` through
`GetAdaptersAddresses`. **macOS** provides `ipAddress` / `ipv6Address` /
`gateway` / `isVpn` through `getifaddrs` and the `sysctl` routing table. **Linux**
reports only the Dart-side IP/IPv6. See
[Platform Support](Platform-Support) for the full matrix.

插件已在三个桌面平台声明。桌面端 SSID / BSSID / 信号强度**恒为 `null`**。
**Windows** 额外通过 `GetAdaptersAddresses` 提供 `ipAddress` / `ipv6Address` /
`gateway` / `macAddress` / `isVpn`；**macOS** 通过 `getifaddrs` 与 `sysctl` 路由表
提供 `ipAddress` / `ipv6Address` / `gateway` / `isVpn`；**Linux** 仅提供 Dart 侧的
IP/IPv6。完整矩阵见
[平台支持](Platform-Support)。

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
