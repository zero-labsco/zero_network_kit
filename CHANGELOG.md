# Changelog

## 1.0.2

### Added / 新增

- **Swift Package Manager support** — iOS and macOS now ship a `Package.swift`
  next to the CocoaPods podspec, so the plugin keeps working in projects that
  have migrated to SwiftPM. Native sources moved to
  `<platform>/zero_network_kit/Sources/zero_network_kit/`.
  - **支持 Swift Package Manager**——iOS 与 macOS 在 CocoaPods podspec 之外新增
    `Package.swift`，使插件在已迁移 SwiftPM 的工程中同样可用。原生源码移至
    `<platform>/zero_network_kit/Sources/zero_network_kit/`。

### Fixed / 修复

- **Package description** — the pub.dev description still advertised only five
  platforms after Web support shipped; it now lists all six.
  - **包描述**——Web 支持上线后，pub.dev 上的描述仍只宣传五个平台，现已列出全部六个。
- **podspec metadata** — replaced the leftover macOS template values (placeholder
  summary, `example.com` homepage, `Your Company` author) and the iOS author with
  the real project metadata, and enabled the privacy manifest resource bundle on
  both platforms.
  - **podspec 元信息**——把 macOS 残留的模板值（占位 summary、`example.com` 主页、
    `Your Company` 作者）与 iOS 的作者替换为真实项目信息，并在两个平台启用隐私清单资源包。

## 1.0.1

### Added / 新增

- **Web platform (partial)** — the package now compiles and runs on Flutter Web.
  Connectivity is backed by `connectivity_plus`, ping falls back to an HTTPS
  round trip, DNS resolution uses DNS-over-HTTPS, and the speed test, quality
  score and benchmarks work unchanged. Capabilities the browser sandbox forbids
  degrade gracefully: native details (SSID / gateway / MAC / VPN) report `null`
  and TCP port checks return an "unavailable" result instead of throwing. Call
  `NetworkCapabilities.current()` to discover the supported set at runtime.
  - **Web 平台（部分支持）**——包现已可在 Flutter Web 上编译运行。连通性由
    `connectivity_plus` 提供，Ping 退化为 HTTPS 往返耗时，DNS 解析改用
    DNS-over-HTTPS，测速、质量评分与基准测试行为不变。浏览器沙箱禁止的能力会优雅降级：
    原生详情（SSID / 网关 / MAC / VPN）返回 `null`，TCP 端口检测返回"不可用"结果而非抛异常。
    运行时可调用 `NetworkCapabilities.current()` 查询当前支持的能力集合。

### Fixed / 修复

- **Speed test on the web** — download and upload requests no longer send a
  `Cache-Control` header. It is not a CORS-safelisted header, so it forced an
  OPTIONS preflight that speed-test endpoints reject, surfacing as
  `Failed to fetch`.
  - **Web 端测速**——下载与上传请求不再携带 `Cache-Control` 头。该头不属于 CORS
    安全头，会触发 OPTIONS 预检，而测速端点会拒绝该预检，最终表现为 `Failed to fetch`。

### Changed / 变更

- **Windows VPN detection** — adapters are now also recognised from the driver
  name in their description (TAP-Windows, Wintun, WireGuard, OpenVPN, …) in
  addition to `IF_TYPE_TUNNEL`. `IF_TYPE_PPP` is deliberately not treated as a
  VPN because PPPoE broadband reports the same interface type.
  - **Windows VPN 检测**——除 `IF_TYPE_TUNNEL` 外，还会依据网卡描述中的驱动名识别
    VPN 网卡（TAP-Windows、Wintun、WireGuard、OpenVPN 等）。有意**不**把
    `IF_TYPE_PPP` 视为 VPN，因为 PPPoE 宽带拨号上报的也是该接口类型。

## 1.0.0

### Added / 新增

- **Connectivity** — `NetworkDiagnostic.checkConnection()` returns a
  `NetworkConnectionInfo` snapshot with transport type, IPv4/IPv6, gateway,
  Wi-Fi SSID, signal strength (dBm), MAC address and VPN detection.
  `NetworkDiagnostic.onConnectivityChanged` streams a fresh snapshot on every
  change.
  - **连通性**——`NetworkDiagnostic.checkConnection()` 返回 `NetworkConnectionInfo`
    快照，包含传输类型、IPv4/IPv6、网关、Wi-Fi SSID、信号强度（dBm）、MAC 地址与
    VPN 检测；`NetworkDiagnostic.onConnectivityChanged` 会在每次变化时推送新快照。
- **Ping** — `NetworkDiagnostic.ping()` measures latency with TCP handshake
  round trips on every platform, and can use the system ICMP `ping` command on
  desktop (`PingMode.icmp`). `PingResult` reports sent/received, packet loss,
  min/avg/max and jitter.
  - **Ping**——`NetworkDiagnostic.ping()` 在各平台以 TCP 握手往返测量延迟，桌面端还
    可使用系统 ICMP `ping` 命令（`PingMode.icmp`）。`PingResult` 提供发送/接收数、
    丢包率、最小/平均/最大耗时与抖动。
- **DNS** — `NetworkDiagnostic.resolve()` queries `system` plus any explicit
  resolvers over raw UDP, using the built-in DNS wire-format codec
  (`DnsPacket`), with concurrent or serialised execution and per-server
  `DnsTestResult`.
  - **DNS**——`NetworkDiagnostic.resolve()` 通过原始 UDP 查询 `system` 及任意指定
    DNS 服务器，使用内置 DNS 报文编解码器（`DnsPacket`），支持并发或串行执行，
    并为每台服务器返回 `DnsTestResult`。
- **Speed test** — `NetworkDiagnostic.runSpeedTest()` measures download and
  upload throughput plus latency/jitter/packet loss, with progress callbacks via
  `SpeedTestProgress`.
  - **测速**——`NetworkDiagnostic.runSpeedTest()` 测量下载与上传速率，并附带延迟、
    抖动与丢包率，通过 `SpeedTestProgress` 回调进度。
- **Port check** — `NetworkDiagnostic.checkPort()` returns a `PortCheckResult`
  (use `isPortOpen()` for a plain boolean) and `scanPorts()` performs
  bounded-concurrency TCP reachability checks.
  - **端口检测**——`NetworkDiagnostic.checkPort()` 返回 `PortCheckResult`（仅需布尔值
    时可用 `isPortOpen()`）；`scanPorts()` 以受限并发执行 TCP 可达性检测。
- **Quality score** — `NetworkDiagnostic.evaluateQuality()` and
  `NetworkQualityEvaluator` produce a 0–100 weighted score with a
  `NetworkQualityLevel` and actionable suggestions.
  - **质量评分**——`NetworkDiagnostic.evaluateQuality()` 与 `NetworkQualityEvaluator`
    产出 0–100 的加权评分，附带 `NetworkQualityLevel` 与可执行的优化建议。
- **Full report** — `NetworkDiagnostic.diagnose()` aggregates every
  probe into a `NetworkDiagnosticReport`.
  - **汇总报告**——`NetworkDiagnostic.diagnose()` 将全部探测结果汇总为
    `NetworkDiagnosticReport`。
- **Benchmarks** — `NetworkBenchmark.runAll()` and friends measure the
  diagnostics API itself and return `BenchmarkSuiteResult`.
  - **基准测试**——`NetworkBenchmark.runAll()` 等方法测量诊断 API 自身的性能，
    返回 `BenchmarkSuiteResult`。
- **Configuration** — `NetworkDiagnosticConfig` centralises hosts, timeouts,
  payload sizes and quality targets; `ZeroNetworkKit.init()` applies it globally
  and `dispose()` releases the owned HTTP client.
  - **配置**——`NetworkDiagnosticConfig` 集中管理主机、超时、负载大小与质量目标；
    `ZeroNetworkKit.init()` 全局生效，`dispose()` 释放其持有的 HTTP 客户端。
- **Native channel** — `getPlatformVersion()` and `getNetworkDetails()`
  implemented for Android (Kotlin) and iOS (Swift).
  - **原生通道**——`getPlatformVersion()` 与 `getNetworkDetails()` 已在 Android
    （Kotlin）与 iOS（Swift）实现。
- **Desktop platforms** — Windows, macOS and Linux are now supported
  (`pubspec.yaml` declares them); `getPlatformVersion()` and `getNetworkDetails()`
  are implemented for each. On desktop, SSID / signal strength are `null`; Windows
  additionally exposes gateway / MAC / VPN via the native layer.
  - **桌面平台**——已支持 Windows、macOS 与 Linux（`pubspec.yaml` 已声明），并为各自
    实现 `getPlatformVersion()` 与 `getNetworkDetails()`。桌面端 SSID 与信号强度为
    `null`；Windows 还通过原生层额外提供网关 / MAC / VPN。
- **Capabilities** — `NetworkDiagnostic.capabilities` returns
  `NetworkCapabilities`, so callers can query-then-call and hide unsupported
  cards (e.g. SSID on desktop).
  - **能力集**——`NetworkDiagnostic.capabilities` 返回 `NetworkCapabilities`，
    调用方可"先查询再调用"，隐藏不支持的卡片（例如桌面端的 SSID）。
- **Advanced API** — services, `ConnectivityAdapter`, `QualityEvaluator` and the
  `DnsPacket` codec moved into `package:zero_network_kit/advanced.dart`; the root
  barrel stays small (models + facades + config).
  - **进阶 API**——各项 service、`ConnectivityAdapter`、`QualityEvaluator` 与
    `DnsPacket` 编解码器已移入 `package:zero_network_kit/advanced.dart`；根 barrel
    保持精简（仅模型 + 门面 + 配置）。
