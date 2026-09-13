# DNS / DNS 解析

`NetworkDiagnostic.resolve()` tests DNS resolution across multiple servers in
parallel, so you can spot the fastest one. Each result is either the system
resolver or a raw UDP query against an explicit server.

`NetworkDiagnostic.resolve()` 并行测试多台 DNS 服务器的解析表现，从而挑出最快的一台。
每条结果要么来自系统解析器，要么是对指定服务器的原始 UDP 查询。

## Basic / 基础

```dart
final results = await NetworkDiagnostic.resolve(
  domain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8', '114.114.114.114'],
  timeout: const Duration(seconds: 5),
  concurrent: true,
  includeSystemResolver: true,
);

for (final r in results) {
  if (r.isSuccess) {
    print('${r.server.padRight(16)} → ${r.resolvedIps.join(", ")} '
          '(${r.responseTimeMs.toStringAsFixed(1)} ms)');
  } else {
    print('${r.server.padRight(16)} ✗ ${r.errorMessage}');
  }
}
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `domain` | `config.dnsDomain` | Domain to resolve |
| `dnsServers` | `config.dnsServers` | Servers queried in parallel (or in series) |
| `timeout` | `config.dnsTimeout` | Timeout of one query |
| `concurrent` | `true` | Query all servers at once |
| `includeSystemResolver` | `false` | Also add a `system` row |

Notes / 说明:

- A row with `server == 'system'` comes from the OS resolver; the others are raw
  UDP queries against the listed IPs, encoded by the built-in `DnsPacket` wire
  codec.
  `server == 'system'` 的行来自系统解析器，其余是对指定 IP 的原始 UDP 查询，由内置
  `DnsPacket` 编解码。
- `includeSystemResolver` defaults to **`false`** at the facade level — pass
  `true` to include it.
  门面层默认**不**包含系统解析器，需显式传 `true`。

### Pick the fastest / 挑出最快的

```dart
final fastest = results
    .where((r) => r.isSuccess)
    .reduce((a, b) => a.responseTimeMs <= b.responseTimeMs ? a : b);
print('fastest resolver: ${fastest.server}');
```
