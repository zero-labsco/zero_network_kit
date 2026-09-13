# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

### Added

- **Connectivity** — `NetworkDiagnostic.checkConnection()` returns a
  `NetworkConnectionInfo` snapshot with transport type, IPv4/IPv6, gateway,
  Wi-Fi SSID, signal strength (dBm), MAC address and VPN detection.
  `NetworkDiagnostic.onConnectivityChanged` streams a fresh snapshot on every
  change.
- **Ping** — `NetworkDiagnostic.ping()` measures latency with TCP handshake
  round trips on every platform, and can use the system ICMP `ping` command on
  desktop (`PingMode.icmp`). `PingResult` reports sent/received, packet loss,
  min/avg/max and jitter.
- **DNS** — `NetworkDiagnostic.resolve()` queries `system` plus any explicit
  resolvers over raw UDP, using the built-in DNS wire-format codec
  (`DnsPacket`), with concurrent or serialised execution and per-server
  `DnsTestResult`.
- **Speed test** — `NetworkDiagnostic.runSpeedTest()` measures download and
  upload throughput plus latency/jitter/packet loss, with progress callbacks via
  `SpeedTestProgress`.
- **Port check** — `NetworkDiagnostic.checkPort()` returns a `PortCheckResult`
  (use `isPortOpen()` for a plain boolean) and `scanPorts()` performs
  bounded-concurrency TCP reachability checks.
- **Quality score** — `NetworkDiagnostic.evaluateQuality()` and
  `NetworkQualityEvaluator` produce a 0–100 weighted score with a
  `NetworkQualityLevel` and actionable suggestions.
- **Full report** — `NetworkDiagnostic.diagnose()` aggregates every
  probe into a `NetworkDiagnosticReport`.
- **Benchmarks** — `NetworkBenchmark.runAll()` and friends measure the
  diagnostics API itself and return `BenchmarkSuiteResult`.
- **Configuration** — `NetworkDiagnosticConfig` centralises hosts, timeouts,
  payload sizes and quality targets; `ZeroNetworkKit.init()` applies it globally
  and `dispose()` releases the owned HTTP client.
- **Native channel** — `getPlatformVersion()` and `getNetworkDetails()`
  implemented for Android (Kotlin) and iOS (Swift).
- **Desktop platforms** — Windows, macOS and Linux are now supported
  (`pubspec.yaml` declares them); `getPlatformVersion()` and `getNetworkDetails()`
  are implemented for each. On desktop, SSID / signal strength are `null`; Windows
  additionally exposes gateway / MAC / VPN via the native layer.
- **Capabilities** — `NetworkDiagnostic.capabilities` returns
  `NetworkCapabilities`, so callers can query-then-call and hide unsupported
  cards (e.g. SSID on desktop).
- **Advanced API** — services, `ConnectivityAdapter`, `QualityEvaluator` and the
  `DnsPacket` codec moved into `package:zero_network_kit/advanced.dart`; the root
  barrel stays small (models + facades + config).
