# Full Report / 汇总报告

`NetworkDiagnostic.diagnose()` runs every probe you ask for and aggregates them
into one `NetworkDiagnosticReport`. A failing sub-test never aborts the run — its
field simply stays empty/`null`.

`NetworkDiagnostic.diagnose()` 运行你指定的各项探测，并汇总为一份
`NetworkDiagnosticReport`。任何子项失败都不会中断整体流程，对应字段保持空。

## Basic / 基础

```dart
final report = await NetworkDiagnostic.diagnose(
  includePing: true,
  includeDns: true,
  includePorts: true,
  includeSpeedTest: true,
  includeUpload: true,
  host: '1.1.1.1',
  dnsDomain: 'example.com',
  dnsServers: const <String>['1.1.1.1', '8.8.8.8'],
  ports: const <int>[80, 443],
);

print(report);                                  // one-line summary
print(report.connection.type.label);
print(report.ping?.averageTime);
print(report.dnsResults.length);
print(report.portResults.where((p) => p.isOpen).length);
print(report.speedTest?.downloadSpeed);
print(report.quality.level.label);
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `includePing` | `true` | Sample latency / jitter / loss |
| `includeDns` | `true` | Sample DNS latency |
| `includePorts` | `false` | Scan ports (off by default) |
| `includeSpeedTest` | `true` | Sample download / upload |
| `includeUpload` | `true` | Include the upload metric |
| `host` | `config.pingHost` | Latency / port target |
| `dnsDomain` / `dnsServers` | from config | DNS target |
| `ports` | `config.probePorts` | Ports scanned when `includePorts` is `true` |

> `includePorts` defaults to `false`, so a default run does not scan ports.
> `includePorts` 默认 `false`，默认运行不会扫描端口。

The report is JSON-encodable via `report.toMap()`.
报告可通过 `report.toMap()` 序列化为 JSON。
