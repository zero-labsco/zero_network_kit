# FAQ / 常见问题

### Do I need to call `init()`? / 需要调用 `init()` 吗？

No. Every API falls back to built-in defaults. Call `ZeroNetworkKit.init()` only
when you want to override defaults (e.g. a custom reachability host or DNS
servers). Connectivity alone works with zero setup.

不需要。每个 API 都走内置默认值。只有在想覆盖默认参数（如自定义可达性主机或 DNS
服务器）时才调用 `ZeroNetworkKit.init()`。单用连通性完全零配置。

### Which platforms are supported? / 支持哪些平台？

Android, iOS, macOS, Windows and Linux. Web is **not** supported.

支持 Android、iOS、macOS、Windows 与 Linux。Web **不支持**。详见
[Platform Support](Platform-Support)。

### Why is `ssid` / `signalStrength` `null` on desktop? / 为什么桌面上的 ssid/信号强度是 null？

Desktop uses tier A: SSID and RSSI require system APIs that aren't exposed on
macOS/Linux/Windows the same way. They are always `null` on desktop; Windows
additionally provides gateway / MAC / DNS / VPN via `GetAdaptersAddresses`.

桌面采用 A 档：SSID 与 RSSI 依赖系统 API，在桌面上不以同样方式暴露，因此恒为 `null`；
Windows 额外通过 `GetAdaptersAddresses` 提供网关 / MAC / DNS / VPN。

### Why does `getNativeNetworkDetails()` return `null`? / 为什么 getNativeNetworkDetails 返回 null？

Either the platform has no such data (e.g. desktop tier A), or the required
permission is missing (e.g. location for Wi-Fi SSID on Android/iOS). The call
never throws — it degrades gracefully.

要么是平台没有该数据（如桌面 A 档），要么是缺权限（如 Android/iOS 上读取 Wi-Fi SSID
需定位权限）。该调用绝不抛异常，会优雅降级。

### Does the speed test use my bandwidth? / 测速会消耗我的流量吗？

Yes — the default endpoints are Cloudflare's public service and download ≈25 MB
by default. Ask for consent on metered connections and override `downloadUrl` /
`uploadUrl` for production.

会——默认端点指向 Cloudflare 公共服务，默认下载约 25 MB。在按量计费网络上请征得同意，
生产环境请替换 `downloadUrl` / `uploadUrl`。

### How do I test my integration without the network? / 如何脱离网络测试我的集成？

Every service is injectable. Implement `ConnectivityAdapter` (or pass fake
service instances) and call `NetworkDiagnostic.configure(...)`, then
`NetworkDiagnostic.reset()` to restore defaults. See
[Usage → Dependency injection](Usage#dependency-injection--tests).

每个服务都可注入。实现 `ConnectivityAdapter`（或直接传入假服务实例）后调用
`NetworkDiagnostic.configure(...)`，再用 `NetworkDiagnostic.reset()` 恢复默认。详见
[用法 → 依赖注入](Usage#dependency-injection--tests)。

### How is this licensed? / 采用什么许可证？

MPL-2.0. See the repository [LICENSE](https://github.com/zero-labsco/zero_network_kit/blob/main/LICENSE).

采用 MPL-2.0。详见仓库 [LICENSE](https://github.com/zero-labsco/zero_network_kit/blob/main/LICENSE)。
