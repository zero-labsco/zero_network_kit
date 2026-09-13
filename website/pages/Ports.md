# Ports / 端口检测

`checkPort()` returns a full `PortCheckResult` for one port; `isPortOpen()` is the
plain boolean convenience; `scanPorts()` runs many ports concurrently with
bounded in-flight connections.

`checkPort()` 返回单个端口的完整 `PortCheckResult`；`isPortOpen()` 是便捷的布尔版；
`scanPorts()` 以有界并发批量扫描多个端口。

## Single port / 单端口

```dart
// Boolean convenience / 便捷布尔版
final open = await NetworkDiagnostic.isPortOpen(
  host: 'example.com',
  port: 443,
  timeout: const Duration(seconds: 3),
);
print(open ? 'HTTPS reachable' : 'HTTPS unreachable');

// Full result with RTT and error message / 含 RTT 与错误信息的完整结果
final result = await NetworkDiagnostic.checkPort(host: 'example.com', port: 443);
print('open=${result.isOpen} rtt=${result.responseTimeMs} ms '
      'err=${result.errorMessage}');
```

## Bulk scan / 批量扫描

```dart
final scan = await NetworkDiagnostic.scanPorts(
  host: 'example.com',
  ports: const <int>[22, 80, 443, 8080, 8443],
  concurrency: 8,
);

for (final r in scan) {
  print('${r.host}:${r.port} '
        '${r.isOpen ? "open" : "closed"} '
        '${r.responseTimeMs.toStringAsFixed(1)} ms '
        '${r.errorMessage ?? ""}');
}
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `ports` (`scanPorts`) | `config.probePorts` (`[80, 443]`) | Ports to probe |
| `concurrency` | `12` | Max in-flight connections |
| `timeout` | `config.portCheckTimeout` | Timeout per port |

> `checkPort()` returns a **`PortCheckResult`** (with `isOpen`, `responseTimeMs`
> and `errorMessage`); use `isPortOpen()` for a plain boolean. When you need the
> round-trip time or the failure reason for a single port, call `checkPort()`
> directly or pass a one-element list to `scanPorts()`:
> `scanPorts(host: 'example.com', ports: [443]).first`.
> `checkPort()` 返回 **`PortCheckResult`**（含 `isOpen`、`responseTimeMs`、
> `errorMessage`）；单端口布尔诉求请用 `isPortOpen()`。需要 RTT 或失败原因时可直接
> 调用 `checkPort()`，或给 `scanPorts(..., ports: [443])` 取单条结果。
