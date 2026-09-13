# Latency / Ping / 延迟探测

`NetworkDiagnostic.ping()` measures round-trip time towards a target host and
reports sent / received counts, packet loss, min/avg/max and jitter.

`NetworkDiagnostic.ping()` 测量到目标主机的往返时间，并给出发送/接收次数、丢包率、
最小/平均/最大耗时与抖动。

## Basic / 基础

```dart
final ping = await NetworkDiagnostic.ping(
  host: '1.1.1.1',
  count: 5,
  timeout: const Duration(seconds: 2),
  interval: const Duration(milliseconds: 200),
  port: 443,
);

print('received : ${ping.received}/${ping.sent}');
print('loss     : ${ping.packetLoss.toStringAsFixed(1)} %');
print('min/avg/max: ${ping.minTime.toStringAsFixed(1)} / '
      '${ping.averageTime.toStringAsFixed(1)} / '
      '${ping.maxTime.toStringAsFixed(1)} ms');
print('jitter   : ${ping.jitter.toStringAsFixed(2)} ms');
print('samples  : ${ping.times}');
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `host` | `config.pingHost` | Target host |
| `count` | `config.pingCount` | Number of probes |
| `timeout` | `config.pingTimeout` | Per-probe timeout |
| `interval` | `config.pingInterval` | Delay between probes |
| `port` | `config.pingPort` | TCP port probed in `PingMode.tcp` |
| `mode` | `PingMode.tcp` | `PingMode.tcp` or `PingMode.icmp` |

## TCP vs ICMP / TCP 与 ICMP

`PingMode.tcp` performs a TCP handshake to `host:port` — the portable equivalent
of ICMP and the **only mode available on Android/iOS**.

`PingMode.tcp` 通过 TCP 握手到 `host:port` 测量往返，是移动端**唯一可用的模式**。

```dart
// Desktop only — falls back gracefully if the `ping` binary is unavailable.
await NetworkDiagnostic.ping(host: '1.1.1.1', count: 4, mode: PingMode.icmp);
```

`ping.isSuccess` is `true` when at least one probe answered; check it before
trusting the averages.

至少一次成功响应时 `isSuccess` 为 `true`，读平均值前建议先判断它。

> A TCP ping needs a **listening port**. Probing `host` with `port: 443` fails if
> that host does not accept TCP/443 — that is "filtered", not "offline". Use
> `mode: PingMode.icmp` on desktop to get closer to real ICMP.
> TCP 探测需要一个**在监听的端口**。对不接受 TCP/443 的主机探测 `port: 443` 会失败——
> 那是“被过滤”，不是“离线”。在桌面上用 `PingMode.icmp` 更接近真实 ICMP。
