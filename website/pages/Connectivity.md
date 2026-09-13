# Connectivity / 连通性

`NetworkDiagnostic.checkConnection()` captures a single snapshot of the current
network; `onConnectivityChanged` emits a fresh snapshot on every transport
change.

`NetworkDiagnostic.checkConnection()` 捕获当前网络的一次快照；`onConnectivityChanged`
在每次传输方式变化时推送新快照。

## Snapshot / 快照

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

| Field | Notes |
| --- | --- |
| `type` | `NetworkType` (`none`, `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `other`) |
| `isConnected` | `true` unless `type` is `none` |
| `ipAddress` / `ipv6Address` | Local IPv4 / IPv6 (Dart `NetworkInterface`) |
| `gateway` / `macAddress` | Native; `null` on desktop except Windows |
| `ssid` / `signalStrength` | Native; **always `null` on desktop** |
| `isVpn` | Native VPN detection |
| `isReachable` | Only filled when `probeReachability: true` |
| `timestamp` | When the snapshot was taken |

> Use `connection.type.label` / `connection.type.id`. There is **no**
> `displayName`.
> 请使用 `connection.type.label` / `connection.type.id`，**没有** `displayName`。

### Parameters / 参数

| Parameter | Default | Meaning |
| --- | --- | --- |
| `includeNativeDetails` | `true` | Also read SSID / gateway / MAC / VPN from the native side |
| `probeReachability` | `false` | Make a real request and fill `isReachable` |
| `probeTimeout` | `3s` | Timeout of that reachability probe |

```dart
// Skip the native channel (cheapest call — good on hot paths).
final quick = await NetworkDiagnostic.checkConnection(includeNativeDetails: false);

// Prove the internet is actually reachable, not just that a NIC is up.
final verified = await NetworkDiagnostic.checkConnection(
  probeReachability: true,
  probeTimeout: const Duration(seconds: 5),
);
if (verified.isReachable == false) {
  print('Interface is up but the internet is unreachable.');
}
```

## Change stream / 变化监听

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

### Connectivity-only: minimal example / 仅连通性：最小示例

If all you need is "am I online, on what transport, what IP, and react to
changes", you only need this page — **no `init()` required**.

如果只需要「在不在線、走什么網络、IP 是多少、切换时通知」，只看本页即可——
**无需 `init()`**。

```dart
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
