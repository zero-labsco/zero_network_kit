# Zero Network Kit

A Flutter plugin for **network diagnostics**: connectivity inspection, latency
probing, DNS resolution, port checks, bandwidth measurement, quality scoring and
micro-benchmarks — on Android, iOS, macOS, Windows and Linux.

一个 Flutter 插件，提供**网络诊断**能力：连通性检测、延迟探测、DNS 解析、端口
检测、带宽测速、质量评分与微基准测试——覆盖 Android、iOS、macOS、Windows 与 Linux。

## ✨ Features / 功能特性

| Feature | Description |
|---------|-------------|
| **Zero setup** | Works out of the box; `init()` only to override defaults / 开箱即用，仅需在想覆盖默认值时才 `init()` |
| **Connectivity** | Transport type, IPv4/IPv6, gateway, SSID, RSSI, MAC, VPN / 传输类型、IPv4/IPv6、网关、SSID、信号强度、MAC、VPN |
| **Latency** | TCP handshake RTT everywhere; system ICMP on desktop / TCP 握手 RTT 全平台可用，桌面额外支持系统 ICMP |
| **DNS** | System resolver + raw UDP against explicit servers / 系统解析器 + 针对指定服务器的原始 UDP 查询 |
| **Ports** | Bounded-concurrency TCP reachability / 有界并发的 TCP 可达性检测 |
| **Speed test** | Download/upload throughput with progress callbacks / 上下行测速，带进度回调 |
| **Quality** | Weighted 0–100 score + level + suggestions / 加权 0–100 分 + 等级 + 建议 |
| **Full report** | One-shot aggregate of every probe / 一次性汇总所有探测 |
| **Benchmarks** | Measures how fast the diagnostics API itself runs / 衡量诊断 API 自身开销 |
| **Capabilities** | Query-then-call; hide unsupported cards (e.g. SSID on desktop) / 先查询后调用，隐藏不支持的卡片 |
| **Graceful degradation** | Missing permission or unreachable sub-service never throws / 缺权限或子服务不可达时只返回 `null`，绝不抛异常 |
| **Hermetic tests** | Every service accepts injected collaborators / 每个服务都支持注入协作对象，便于单测 |

## 📚 Table of Contents / 目录

| Page | Description |
|------|-------------|
| [Getting Started](Getting-Started) | Quick start guide / 快速开始 |
| [Installation](Installation) | How to install / 安装方式 |
| [Usage](Usage) | Global config, serialisation, dependency injection / 全局配置、序列化、依赖注入 |
| [Connectivity](Connectivity) | Connection snapshot & change stream / 连通性快照与变化监听 |
| [Latency / Ping](Ping) | TCP & ICMP latency probing / 延迟探测 |
| [DNS](DNS) | Resolver comparison across servers / DNS 解析 |
| [Ports](Ports) | Single port & bulk scan / 端口检测 |
| [Speed Test](Speed-Test) | Download/upload throughput / 测速 |
| [Quality Score](Quality) | Weighted scoring / 质量评分 |
| [Full Report](Full-Report) | One-shot aggregate / 汇总报告 |
| [Benchmarks](Benchmark) | Micro-benchmarks / 微基准 |
| [Platform Support](Platform-Support) | Capability matrix & native details / 能力矩阵与原生详情 |
| [API Reference](API-Reference) | Model field reference & gotchas / 模型字段速查与陷阱 |
| [FAQ](FAQ) | Frequently asked questions / 常见问题 |

## 🔗 Links / 链接

- [GitHub](https://github.com/zero-labsco/zero_network_kit)
- [Official Website](https://www.zerolabsco.com/)
- [pub.dev](https://pub.dev/packages/zero_network_kit)

## 📄 License / 许可证

This project is licensed under the **MPL-2.0**.

本项目采用 **MPL-2.0** 许可证。

This plugin is provided "as is", without warranty of any kind. The author assumes
no responsibility or liability for the functionality, security, or any
consequences arising from the use of modified versions or derivative projects.

本插件按"原样"提供，不提供任何担保。作者不对修改版或衍生项目的功能、安全性及
任何使用后果承担责任。
