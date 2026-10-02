# Changelog

## 1.1.0

### Fixed / 修复

- **macOS ICMP ping** — the system `ping` timeout unit is now per platform:
  `-w` (Windows) and `-W` (macOS/BSD) take **milliseconds** while `-W` (Linux
  iputils) takes **seconds**. macOS previously reused the Linux meaning, so a
  3 s timeout was passed as `3` → 3 ms and every probe timed out.
  - **macOS ICMP ping**——系统 `ping` 的超时单位改为按平台区分：`-w`（Windows）与
    `-W`（macOS/BSD）以**毫秒**为单位，而 `-W`（Linux iputils）以**秒**为单位。
    此前 macOS 误用了 Linux 的语义，3 秒超时被当作 3 毫秒，导致探测必然超时。
- **TCP ping no longer bills DNS resolution** — the host is resolved once before
  the probes, so lookup time (and its cache jitter) is no longer counted as round
  trip time.
  - **TCP ping 不再计入域名解析耗时**——探测前先解析一次目标地址，解析耗时（及其缓存抖动）不再被算作往返时间。
- **HTTP client leaks** — `runSpeedTest` now creates its client inside `try`, and
  `ZeroNetworkKit.init` closes the previously owned client before adopting a new
  one, so neither a throwing ping nor a second `init(httpClient: …)` can leak it.
  - **HTTP 客户端泄漏**——`runSpeedTest` 改为在 `try` 内创建客户端，`ZeroNetworkKit.init` 在启用新客户端前先关闭旧的，ping 抛异常或再次 `init(httpClient: …)` 都不会再泄漏。
- **Configuration state** — `ZeroNetworkKit.config` now forwards to
  `NetworkDiagnostic.config` instead of keeping a second copy, so `init()` no
  longer silently resets a configuration applied through `configure()`.
  - **配置状态**——`ZeroNetworkKit.config` 改为直接转发 `NetworkDiagnostic.config`，不再另存一份副本，`init()` 不会再无声重置通过 `configure()` 设置的配置。
- **DNS latency inflation** — a lost AAAA answer no longer stretches the raw-UDP
  lookup to the full timeout; once one of the paired A / AAAA queries answers, the
  sibling gets a short grace window (⅕ of the timeout, clamped to 100 ms – 1 s).
  A 20 ms lookup was previously reported as the full 5 s timeout.
  - **DNS 延迟虚高**——AAAA 应答丢失不再把原始 UDP 查询拖到超时上限；A / AAAA 中任一应答到达后，另一项只获得一个短宽限窗口（超时的五分之一，夹在 100 毫秒至 1 秒）。此前一次 20 毫秒的解析会被记成 5 秒。
- **Non-ASCII DNS queries** — query labels are encoded with UTF-8 instead of
  `String.codeUnits`, which silently truncated any code unit above 255 (e.g. CJK
  domains) into a corrupt message.
  - **非 ASCII DNS 查询**——查询标签改用 UTF-8 编码，此前使用 `String.codeUnits` 会把大于 255 的码元（如中文域名）静默截断成错误报文。
- **Offline no longer reported as online** — `NetworkConnectionInfo.isConnected`
  only falls back to a local IP when the connectivity adapter reported nothing at
  all; an explicit `none` wins, so a VM / Docker-bridge IP cannot mask an offline
  device.
  - **离线不再被判为在线**——`NetworkConnectionInfo.isConnected` 仅在连通性适配器完全没给出结论时才用本地 IP 兜底；适配器明确报告的 `none` 优先，虚拟机 / Docker 网桥的 IP 不再掩盖离线状态。
- **iOS VPN false positives** — `isVpn` no longer matches any `utun` interface:
  iOS keeps several of them alive (AWDL, AirDrop, Private Relay), so a tunnel now
  requires a routable IPv4 address.
  - **iOS VPN 误判**——`isVpn` 不再只要存在 `utun` 接口就为真：iOS 常驻多个此类接口（AWDL、AirDrop、私隐中转），现要求其拥有可路由的 IPv4 地址才认定为隧道。
- **macOS native details** — `getNetworkDetails` returns IP / IPv6 / VPN like the
  iOS implementation instead of an empty map; the two Darwin sources now share the
  same `getifaddrs` logic.
  - **macOS 原生详情**——`getNetworkDetails` 改为像 iOS 那样返回 IP / IPv6 / VPN，而非空 map；两个 Darwin 平台现在共用同一套 `getifaddrs` 逻辑。
- **Web DoH** — the domain is passed through `Uri.queryParameters` (so `&`,
  `=` and Unicode can no longer break the query) and AAAA is queried alongside A,
  matching the native resolver.
  - **Web 端 DoH**——域名改为通过 `Uri.queryParameters` 传递（`&`、`=` 与 Unicode 字符不再破坏查询串），并同时查询 AAAA，与原生解析器保持一致。

### Changed / 变更

- **`diagnose()` runs its independent probes concurrently** — latency, DNS and
  port probes now run together, and each is individually guarded, so the round
  lasts as long as the slowest probe and a failing sub-test can never abort the
  run (previously only the speed test was guarded).
  - **`diagnose()` 并发执行独立探测**——延迟、DNS 与端口探测现在同时执行并各自兜住异常，整轮耗时等于最慢的一项，且任何子项失败都不会中断整体流程（此前只有测速被保护）。
- **Benchmark throughput** — `operationsPerSecond` is derived from the successful
  iterations only; failed ones (typically a full timeout each) no longer dilute it.
  - **基准吞吐**——`operationsPerSecond` 只依据成功的迭代计算，失败迭代（通常各占满一次超时）不再稀释该数值。

### Added / 新增

- **`gateway` on iOS and macOS** — the default IPv4 gateway is now read from the
  `sysctl` routing table (the same source as `netstat -rn`), so `gateway` is
  populated on iOS and macOS too. This needs **no permission, no entitlement and
  no extra framework** — unlike SSID / RSSI, which stay `null` on iOS. `gateway`
  is now available on Android, iOS, macOS and Windows; only Linux and Web report
  `null`.
  - **iOS 与 macOS 的 `gateway`**——默认 IPv4 网关改为从 `sysctl` 路由表读取（与 `netstat -rn` 同源），因此 iOS 与 macOS 上该字段也有值了。这**不需要任何权限、entitlement 或额外 framework**——与 iOS 上仍为 `null` 的 SSID / 信号强度不同。`gateway` 现在在 Android、iOS、macOS 与 Windows 上可用，仅 Linux 与 Web 为 `null`。
- **`NetworkCapability.wifiDetails`** — a new capability flag for SSID / BSSID /
  signal strength. It is **Android-only**: iOS does not request the *Access WiFi
  Information* capability and desktop / web never read Wi-Fi details, so
  `nativeDetails` alone was too coarse and made UIs render rows that are always
  empty.
  - **`NetworkCapability.wifiDetails`**——新增的 SSID / BSSID / 信号强度能力标志，**仅 Android**：iOS 未申请 *Access WiFi Information* 能力，桌面与 Web 从不读取 Wi-Fi 详情，仅凭 `nativeDetails` 过于粗糙，会让 UI 渲染出恒为空的行。
- **`DnsTestResult.averageLatency`** — shared helper returning the mean response
  time of the successful results, or `null` when all of them failed. Failures are
  excluded because their duration is the full timeout.
  - **`DnsTestResult.averageLatency`**——共享辅助方法，返回成功结果的平均响应耗时，全部失败时为 `null`。失败项被排除，因为其耗时等于超时上限。
- **`PingService.icmpArgs` / `DnsService.siblingGrace`** — exposed so the
  per-platform ICMP timeout unit and the A/AAAA grace window can be unit tested.
  Both throw / return zero on the web, which keeps the two platform branches of
  the conditional export API-compatible.
  - **`PingService.icmpArgs` / `DnsService.siblingGrace`**——对外暴露，以便对分平台的 ICMP 超时单位与 A/AAAA 宽限窗口做单元测试。Web 分支分别抛错 / 返回零，从而让条件导出的两个分支保持 API 兼容。

## 1.0.5

### Fixed / 修复

- **Upload speed measurement** — the upload duration now stops as soon as the
  request body is fully sent, so the server's response download no longer
  inflates the measured upload throughput (and the reported `SpeedTestProgress`
  value stays consistent with the final result).
  - **上传速率测量**——上传耗时改为在请求体完全发出时即停止，服务器回包下载时间不再计入，上传速率与进度回调数值保持一致。
- **Web connectivity listener leak** — `WebConnectivityAdapter.onConnectivityChanged`
  now attaches the `online` / `offline` browser listeners on the first
  subscription and detaches them on the last cancellation, so repeated
  subscriptions no longer accumulate global event listeners.
  - **Web 连通性监听泄漏**——`WebConnectivityAdapter.onConnectivityChanged` 改为首次订阅时挂载、末次取消时移除浏览器的 `online` / `offline` 监听，反复订阅不再累积全局监听。
- **Web DNS DoH contract** — an explicit DNS server with no known DoH endpoint now
  returns the documented "unsupported" result instead of probing an arbitrary
  `https://<server>/dns-query` URL.
  - **Web 端 DNS DoH 契约**——对没有已知 DoH 端点的显式 DNS 服务器，现在按文档返回"不支持"结果，而非去请求一个未必提供 DoH 的 `https://<server>/dns-query` 地址。
- **Web ping RTT** — the TCP-probe ping on the web stops the timer at the response
  headers, so a large response body no longer inflates the reported latency.
  - **Web 端 Ping RTT**——Web 端的 TCP 探测 ping 在收到响应头即停表，响应体大小不再抬高测得的延迟。

### Added / 新增

- **IPv6 DNS resolution** — the raw-UDP resolver now sends both A and AAAA
  queries and binds a wildcard socket that matches the target server's address
  family, so IPv6 answers are resolved too (previously only IPv4).
  - **IPv6 DNS 解析**——原始 UDP 解析器现在同时发送 A 与 AAAA 查询，并按目标服务器地址族绑定通配套接字，从而也能解析出 IPv6 地址（此前仅限 IPv4）。

## 1.0.4

### Fixed / 修复

- **Web/WASM build** — the platform-specific implementations are now selected by
  gating the `dart:io` variants behind `dart.library.io`, using the browser-based
  variants as the fallback. Previously the conditional exports defaulted to the
  `dart:io` variants, so an environment that does not define `dart.library.html`
  still resolved them and pulled `dart:io` into the Web build. Runtime behaviour
  is unchanged on every supported platform: native still uses the `dart:io`
  variants, the Web still uses the browser-based ones.
  - **Web/WASM 构建**——各平台实现改为按 `dart.library.io` 条件引入原生版本，并以
    浏览器版本作为兜底。此前条件导出默认使用 `dart:io` 版本，未定义
    `dart.library.html` 的环境仍会解析到它们，从而把 `dart:io` 带入 Web 构建。
    各平台运行时行为不变：原生仍使用 `dart:io` 版本，Web 仍使用基于浏览器的版本。

## 1.0.3

### Fixed / 修复

- **WASM compatibility** — the web connectivity implementation no longer imports
  `connectivity_plus` (whose non-web default branch pulls in the Linux-only `nm`
  package). It now talks to the browser directly through `package:web`
  (`navigator.onLine` plus the `online` / `offline` events), so the package scores
  full marks (20/20) on pub.dev's platform-support check and compiles with
  `flutter build web --wasm`. `connectivity_plus` is still used on native platforms.
  - **WASM 兼容性**——Web 端连通性实现不再导入 `connectivity_plus`（其非 Web 默认分支会引入仅限
    Linux 的 `nm` 包），改为通过 `package:web`（`navigator.onLine` 与 `online` / `offline`
    事件）直接与浏览器交互。包在 pub.dev 平台支持项中得满分（20/20），且可用
    `flutter build web --wasm` 编译。`connectivity_plus` 在原生平台仍继续使用。

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
