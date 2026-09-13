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
      title: 'Zero Network Kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const DiagnosticHomePage(),
    );
  }
}

/// 诊断看板 / Diagnostic dashboard.
class DiagnosticHomePage extends StatefulWidget {
  const DiagnosticHomePage({super.key});

  @override
  State<DiagnosticHomePage> createState() => _DiagnosticHomePageState();
}

class _DiagnosticHomePageState extends State<DiagnosticHomePage> {
  String _platformVersion = 'unknown';
  NetworkConnectionInfo? _connection;
  PingResult? _ping;
  List<DnsTestResult> _dns = const <DnsTestResult>[];
  SpeedTestResult? _speed;
  NetworkQualityScore? _quality;
  BenchmarkSuiteResult? _benchmark;
  String? _busyLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
  }

  Future<void> _loadPlatformVersion() async {
    try {
      final version = await ZeroNetworkKit.getPlatformVersion();
      if (!mounted) return;
      setState(() => _platformVersion = version ?? 'unknown');
    } catch (_) {
      if (!mounted) return;
      setState(() => _platformVersion = 'unavailable');
    }
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busyLabel = label;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero Network Kit'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'platform: $_platformVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_busyLabel != null) const LinearProgressIndicator(),
          if (_error != null) _ErrorBanner(message: _error!),
          _ActionCard(
            title: 'Connection',
            description:
                'Transport type, IP, gateway and VPN (SSID / signal on mobile)',
            onPressed: () => _run('connection', () async {
              final info = await NetworkDiagnostic.checkConnection();
              setState(() => _connection = info);
            }),
            body: _connection == null
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      'connected': '${_connection!.isConnected}',
                      'type': _connection!.type.label,
                      'ipv4': _connection!.ipAddress ?? '-',
                      'ipv6': _connection!.ipv6Address ?? '-',
                      'gateway': _connection!.gateway ?? '-',
                      'mac': _connection!.macAddress ?? '-',
                      'vpn': '${_connection!.isVpn}',
                      if (NetworkDiagnostic.capabilities.supports(
                        NetworkCapability.nativeDetails,
                      )) ...<String, String>{
                        'ssid': _connection!.ssid ?? '-',
                        'signal': _connection!.signalStrength == null
                            ? '-'
                            : '${_connection!.signalStrength} dBm',
                      },
                    },
                  ),
          ),
          _ActionCard(
            title: 'Ping',
            description: 'TCP handshake round trip towards 1.1.1.1',
            onPressed: () => _run('ping', () async {
              final result = await NetworkDiagnostic.ping(count: 5);
              setState(() => _ping = result);
            }),
            body: _ping == null
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      'host': _ping!.host,
                      'sent/received': '${_ping!.sent}/${_ping!.received}',
                      'packet loss': '${_ping!.packetLoss.toStringAsFixed(1)}%',
                      'min/avg/max':
                          '${_ping!.minTime.toStringAsFixed(1)} / '
                          '${_ping!.averageTime.toStringAsFixed(1)} / '
                          '${_ping!.maxTime.toStringAsFixed(1)} ms',
                      'jitter': '${_ping!.jitter.toStringAsFixed(2)} ms',
                    },
                  ),
          ),
          _ActionCard(
            title: 'DNS',
            description: 'Raw UDP queries against public resolvers',
            onPressed: () => _run('dns', () async {
              final results = await NetworkDiagnostic.resolve(
                includeSystemResolver: true,
              );
              setState(() => _dns = results);
            }),
            body: _dns.isEmpty
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      for (final result in _dns)
                        result.server:
                            '${result.isSuccess ? result.resolvedIps.join(", ") : (result.errorMessage ?? "failed")}'
                            ' (${result.responseTimeMs.toStringAsFixed(1)} ms)',
                    },
                  ),
          ),
          _ActionCard(
            title: 'Speed test',
            description: 'Download/upload throughput and latency',
            onPressed: () => _run('speed', () async {
              final result = await NetworkDiagnostic.runSpeedTest();
              setState(() => _speed = result);
            }),
            body: _speed == null
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      'server': _speed!.server ?? '-',
                      'download':
                          '${_speed!.downloadSpeed.toStringAsFixed(2)} Mbps',
                      'upload':
                          '${_speed!.uploadSpeed.toStringAsFixed(2)} Mbps',
                      'ping': '${_speed!.ping.toStringAsFixed(1)} ms',
                      'transferred':
                          '${(_speed!.downloadedBytes / 1048576).toStringAsFixed(1)} MiB down / '
                          '${(_speed!.uploadedBytes / 1048576).toStringAsFixed(1)} MiB up',
                    },
                  ),
          ),
          _ActionCard(
            title: 'Quality score',
            description: 'Weighted score across latency, DNS and bandwidth',
            onPressed: () => _run('quality', () async {
              final score = await NetworkDiagnostic.evaluateQuality();
              setState(() => _quality = score);
            }),
            body: _quality == null
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      'score':
                          '${_quality!.score.toStringAsFixed(1)} / 100 (${_quality!.level.label})',
                      for (final entry in _quality!.metrics.entries)
                        entry.key: entry.value.toStringAsFixed(2),
                      'suggestions': _quality!.suggestions.join(' · '),
                    },
                  ),
          ),
          _ActionCard(
            title: 'Full diagnostic',
            description: 'One shot report covering every probe above',
            onPressed: () => _run('report', () async {
              final report = await NetworkDiagnostic.diagnose(
                includeSpeedTest: false,
                includePorts: true,
              );
              setState(() {
                _connection = report.connection;
                _ping = report.ping;
                _dns = report.dnsResults;
                _quality = report.quality;
              });
            }),
          ),
          _ActionCard(
            title: 'Benchmark the API',
            description: 'Measure how fast the diagnostic API itself runs',
            onPressed: () => _run('benchmark', () async {
              final suite = await NetworkBenchmark.runAll(
                iterations: 5,
                warmupIterations: 1,
              );
              setState(() => _benchmark = suite);
            }),
            body: _benchmark == null
                ? null
                : _KeyValueList(
                    entries: <String, String>{
                      for (final result in _benchmark!.results)
                        result.testName:
                            'avg ${(result.averageDuration.inMicroseconds / 1000).toStringAsFixed(2)} ms · '
                            '${result.operationsPerSecond.toStringAsFixed(1)} ops/s',
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.onPressed,
    this.body,
  });

  final String title;
  final String description;
  final Future<void> Function() onPressed;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onPressed, child: const Text('Run')),
            if (body != null) ...<Widget>[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              body!,
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.entries});

  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  children: <TextSpan>[
                    TextSpan(
                      text: '${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: entry.value),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
