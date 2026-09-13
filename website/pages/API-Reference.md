# API Reference / 接口参考

A condensed field reference for every public model. For copy-paste examples of
each method, see the capability pages.

这里是每个公开模型的字段速查。每个方法的复制即用示例请见各能力页面。

## `NetworkType`

| Member | Notes |
| --- | --- |
| values | `none`, `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `other` |
| `label` | Human readable: `'Wi-Fi'`, `'Mobile'`, … |
| `id` | Stable English identifier (`name`), safe to persist |
| `isConnected` | `true` unless `none` |
| `NetworkType.fromRaw(Object?)` | Parses a raw platform string |

## `NetworkConnectionInfo`

`isConnected`, `type`, `ssid`, `signalStrength` (dBm), `ipAddress`,
`ipv6Address`, `gateway`, `macAddress`, `isVpn`, `isReachable`, `timestamp`,
plus `copyWith({bool? isReachable})`.

## `PingResult`

Fields `host`, `port`, `mode`, `sent`, `received`, `times`, `timestamp`;
derived getters `lost`, `packetLoss` (%), `minTime`, `maxTime`, `averageTime`,
`jitter`, `isSuccess`.

## `DnsTestResult`

Fields `server`, `domain`, `isSuccess`, `responseTime`, `resolvedIps`,
`errorMessage`, `timestamp`; derived `responseTimeMs`, `primaryAddress`.

## `PortCheckResult`

Fields `host`, `port`, `isOpen`, `responseTime`, `errorMessage`, `timestamp`;
derived `responseTimeMs`.

## `SpeedTestResult`

Fields `downloadSpeed`, `uploadSpeed` (Mbps), `ping` (ms), `jitter` (ms),
`packetLoss` (%), `downloadedBytes`, `uploadedBytes`, `downloadDuration`,
`uploadDuration`, `server`, `timestamp`; derived `duration`; static helper
`SpeedTestResult.mbpsFromBytes(bytes, elapsed)`.

## `SpeedTestProgress` / `SpeedTestPhase`

`phase` (`download`, `upload`, `completed`), `bytes`, `elapsed`, `speedMbps`.

## `NetworkQualityScore` / `NetworkQualityLevel`

`score` (0–100), `level`, `metrics` (`Map<String, double>`), `suggestions`,
`timestamp`; `NetworkQualityLevel.fromScore(double)`, `level.label`.

## `NetworkDiagnosticReport`

`connection`, `ping`, `dnsResults`, `portResults`, `speedTest`, `quality`,
`timestamp`.

## `BenchmarkResult` / `BenchmarkSuiteResult`

`BenchmarkResult`: `testName`, `iterations`, `totalDuration`,
`averageDuration`, `minDuration`, `maxDuration`, `standardDeviation`,
`operationsPerSecond`, `failures`, `timestamp`.
`BenchmarkSuiteResult`: `suiteName`, `results`, `totalDuration`, `timestamp`,
and `suite['name']`.

## Gotchas / 常见陷阱

1. **`type.label`, not `displayName`.** `NetworkType` exposes `label` / `id`.
2. **`checkPort()` returns `PortCheckResult`.** Use `isPortOpen()` for a plain
   boolean, or `scanPorts(..., ports: [p]).first` for RTT / error message.
3. **`includeSystemResolver` defaults to `false`.** Pass `true` to add the
   `system` DNS row.
4. **A TCP ping needs a listening port.** Probing `host` with `port: 443` fails
   if that host does not accept TCP/443 — that is "filtered", not "offline". Use
   `mode: PingMode.icmp` on desktop to get closer to real ICMP.
5. **`PingMode.icmp` is desktop-only** and silently degrades when the `ping`
   binary is unavailable.
6. **The speed test moves real traffic** (≈25 MB download by default). Ask for
   consent before running it on a metered connection.
7. **Missing permissions degrade, they never throw.** A missing location
   permission yields `ssid == null`; the rest of the snapshot still arrives.
8. **`includePorts` is `false` by default** in `diagnose()`.
9. **`init()` is optional, but `dispose()` only closes the client the plugin
   owns** — an `httpClient` you injected stays open, so close it yourself.

> Full source-level API docs live in the repo:
> [API.md](https://github.com/zero-labsco/zero_network_kit/blob/main/API.md)
> (English) and
> [API_zh.md](https://github.com/zero-labsco/zero_network_kit/blob/main/API_zh.md)
> (简体中文).
> 完整源码级 API 文档见仓库内的
> [API.md](https://github.com/zero-labsco/zero_network_kit/blob/main/API.md)
> 与 [API_zh.md](https://github.com/zero-labsco/zero_network_kit/blob/main/API_zh.md)。
