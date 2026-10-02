import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  ZeroNetworkKit.init(
    config: const NetworkDiagnosticConfig(
      pingHost: '1.1.1.1',
      dnsDomain: 'www.google.com',
    ),
  );
  runApp(const ZeroNetworkKitExampleApp());
}

/// 示例应用 / Demo application for the plugin.
class ZeroNetworkKitExampleApp extends StatelessWidget {
  const ZeroNetworkKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zero_network_kit demo',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const DiagnosticPage(),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B57D0),
      brightness: brightness,
    ),
  );
}

/// 诊断看板 / Diagnostic dashboard.
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  String _platform = '—';
  NetworkConnectionInfo? _connection;
  PingResult? _ping;
  List<DnsTestResult> _dns = const <DnsTestResult>[];
  List<PortCheckResult> _ports = const <PortCheckResult>[];
  SpeedTestResult? _speed;
  NetworkQualityScore? _quality;
  BenchmarkSuiteResult? _benchmark;

  String? _busy;
  String? _error;
  StreamSubscription<NetworkConnectionInfo>? _watch;
  int _changes = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlatform());
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    super.dispose();
  }

  Future<void> _loadPlatform() async {
    final version = await ZeroNetworkKit.getPlatformVersion().catchError(
      (_) => 'unavailable',
    );
    if (!mounted) return;
    setState(() => _platform = version ?? 'unknown');
  }

  /// 串行化所有探测：同一时刻只允许一轮诊断在跑 / Serialises the probes: only one
  /// diagnostic round may run at a time.
  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = label;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _toggleWatch() {
    final subscription = _watch;
    if (subscription != null) {
      unawaited(subscription.cancel());
      setState(() => _watch = null);
      return;
    }
    setState(() {
      _watch = NetworkDiagnostic.onConnectivityChanged.listen((info) {
        if (!mounted) return;
        setState(() {
          _changes += 1;
          _connection = info;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = NetworkDiagnostic.capabilities;
    final busy = _busy != null;

    return Scaffold(
      appBar: AppBar(title: const Text('zero_network_kit')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: <Widget>[
                if (busy) const LinearProgressIndicator(minHeight: 2),
                if (_error != null) _ErrorCard(message: _error!),
                _Section(
                  title: 'Environment',
                  child: Column(
                    children: <Widget>[
                      _Row('platform', _platform),
                      _Row(
                        'capabilities',
                        '${capabilities.supported.length}'
                            '/${NetworkCapability.values.length}',
                      ),
                      _Row('watching', _watch == null ? 'off' : '$_changes'),
                    ],
                  ),
                ),
                _Section(
                  title: 'Run',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton(
                        onPressed: busy ? null : _runDiagnostics,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Full diagnostic'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _Action('Connection', busy ? null : _runConnection),
                          _Action('Ping', busy ? null : _runPing),
                          _Action('DNS', busy ? null : _runDns),
                          if (capabilities.supports(
                            NetworkCapability.portCheck,
                          ))
                            _Action('Ports', busy ? null : _runPorts),
                          _Action('Speed', busy ? null : _runSpeed),
                          _Action('Quality', busy ? null : _runQuality),
                          _Action('Benchmark', busy ? null : _runBenchmark),
                          _Action(
                            _watch == null ? 'Watch' : 'Stop watching',
                            _toggleWatch,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_connection != null)
                  _Section(
                    title: 'Connection',
                    child: Column(
                      children: <Widget>[
                        _Row(
                          'connected',
                          '${_connection!.isConnected}'
                              ' · ${_connection!.type.label}',
                        ),
                        _Row('ipv4', _connection!.ipAddress ?? '—'),
                        _Row('ipv6', _connection!.ipv6Address ?? '—'),
                        _Row('gateway', _connection!.gateway ?? '—'),
                        // 只有 Android 原生层真正读取 Wi-Fi 详情；iOS 未申请
                        // *Access WiFi Information* 能力，故不展示这两行 /
                        // Only the Android native layer reads Wi-Fi details;
                        // iOS does not request the *Access WiFi Information*
                        // capability, so these two rows are hidden there.
                        if (capabilities.supports(
                          NetworkCapability.wifiDetails,
                        )) ...<Widget>[
                          _Row('ssid', _connection!.ssid ?? '—'),
                          _Row(
                            'signal',
                            _connection!.signalStrength == null
                                ? '—'
                                : '${_connection!.signalStrength} dBm',
                          ),
                        ],
                        _Row('vpn', '${_connection!.isVpn}'),
                      ],
                    ),
                  ),
                if (_ping != null)
                  _Section(
                    title: 'Latency',
                    child: Column(
                      children: <Widget>[
                        _Row('host', '${_ping!.host}:${_ping!.port ?? 443}'),
                        _Row('sent', '${_ping!.sent} / ${_ping!.received}'),
                        _Row(
                          'loss',
                          '${_ping!.packetLoss.toStringAsFixed(1)} %',
                        ),
                        _Row(
                          'min / avg / max',
                          '${_ping!.minTime.toStringAsFixed(1)} / '
                              '${_ping!.averageTime.toStringAsFixed(1)} / '
                              '${_ping!.maxTime.toStringAsFixed(1)} ms',
                        ),
                        _Row(
                          'jitter',
                          '${_ping!.jitter.toStringAsFixed(2)} ms',
                        ),
                      ],
                    ),
                  ),
                if (_dns.isNotEmpty)
                  _Section(
                    title: 'DNS',
                    child: Column(
                      children: <Widget>[
                        for (final result in _dns)
                          _Row(
                            result.server,
                            result.isSuccess
                                ? '${result.resolvedIps.join(' ')}'
                                      '  ${result.responseTimeMs.toStringAsFixed(1)} ms'
                                : '${result.errorMessage ?? 'failed'}'
                                      '  ${result.responseTimeMs.toStringAsFixed(1)} ms',
                          ),
                      ],
                    ),
                  ),
                if (_ports.isNotEmpty)
                  _Section(
                    title: 'Ports',
                    child: Column(
                      children: <Widget>[
                        for (final result in _ports)
                          _Row(
                            '${result.port}',
                            result.isOpen
                                ? 'open  ${result.responseTime.inMilliseconds} ms'
                                : 'closed',
                          ),
                      ],
                    ),
                  ),
                if (_speed != null)
                  _Section(
                    title: 'Throughput',
                    child: Column(
                      children: <Widget>[
                        _Row('server', _speed!.server ?? '—'),
                        _Row(
                          'download',
                          '${_speed!.downloadSpeed.toStringAsFixed(2)} Mbps',
                        ),
                        _Row(
                          'upload',
                          '${_speed!.uploadSpeed.toStringAsFixed(2)} Mbps',
                        ),
                        _Row(
                          'transferred',
                          '${(_speed!.downloadedBytes / 1048576).toStringAsFixed(1)}'
                              ' / ${(_speed!.uploadedBytes / 1048576).toStringAsFixed(1)} MiB',
                        ),
                      ],
                    ),
                  ),
                if (_quality != null)
                  _Section(
                    title: 'Quality',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              _quality!.score.toStringAsFixed(0),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ 100 · ${_quality!.level.label}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final entry in _quality!.metrics.entries)
                          _Row(entry.key, entry.value.toStringAsFixed(2)),
                        const SizedBox(height: 12),
                        Text(
                          _quality!.suggestions.join('\n'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                if (_benchmark != null)
                  _Section(
                    title: 'API benchmark',
                    note: 'How long the diagnostic API itself takes, per call.',
                    child: Column(
                      children: <Widget>[
                        for (final result in _benchmark!.results)
                          _Row(
                            result.testName,
                            '${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms'
                            ' · ${result.operationsPerSecond.toStringAsFixed(0)} ops/s',
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runDiagnostics() => _run('diagnostics', () async {
    final report = await NetworkDiagnostic.diagnose(
      includeSpeedTest: false,
      includePorts: true,
    );
    if (!mounted) return;
    setState(() {
      _connection = report.connection;
      _ping = report.ping;
      _dns = report.dnsResults;
      _ports = report.portResults;
      _quality = report.quality;
    });
  });

  Future<void> _runConnection() => _run('connection', () async {
    final info = await NetworkDiagnostic.checkConnection(
      probeReachability: true,
    );
    if (!mounted) return;
    setState(() => _connection = info);
  });

  Future<void> _runPing() => _run('ping', () async {
    final result = await NetworkDiagnostic.ping(count: 5);
    if (!mounted) return;
    setState(() => _ping = result);
  });

  Future<void> _runDns() => _run('dns', () async {
    final results = await NetworkDiagnostic.resolve(
      includeSystemResolver: true,
    );
    if (!mounted) return;
    setState(() => _dns = results);
  });

  Future<void> _runPorts() => _run('ports', () async {
    final results = await NetworkDiagnostic.scanPorts(host: '1.1.1.1');
    if (!mounted) return;
    setState(() => _ports = results);
  });

  /// 测速会真实下载数十 MB，因此只在显式点击时执行 / The speed test really
  /// transfers tens of MB, so it only runs on an explicit tap.
  Future<void> _runSpeed() => _run('speed', () async {
    final result = await NetworkDiagnostic.runSpeedTest(
      onProgress: (progress) => debugPrint('$progress'),
    );
    if (!mounted) return;
    setState(() => _speed = result);
  });

  Future<void> _runQuality() => _run('quality', () async {
    final score = await NetworkDiagnostic.evaluateQuality(
      includeSpeedTest: false,
    );
    if (!mounted) return;
    setState(() => _quality = score);
  });

  Future<void> _runBenchmark() => _run('benchmark', () async {
    final suite = await NetworkBenchmark.runAll(
      iterations: 5,
      warmupIterations: 1,
    );
    if (!mounted) return;
    setState(() => _benchmark = suite);
  });
}

/// 一个带标题的分区卡片 / A titled card section.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            if (note != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 固定宽度的标签 + 等宽数值 / Fixed-width label next to a monospaced value.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 次要操作按钮 / Secondary action button.
class _Action extends StatelessWidget {
  const _Action(this.label, this.onPressed);

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

/// 错误提示卡片 / Error card.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline, size: 20, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
