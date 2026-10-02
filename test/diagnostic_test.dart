import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/advanced.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  tearDown(NetworkDiagnostic.reset);

  group('NetworkDiagnostic.diagnose', () {
    test('a failing sub-probe never aborts the run', () async {
      NetworkDiagnostic.configure(
        connectivity: _FakeConnectivityService(),
        ping: _ThrowingPingService(),
        dns: _ThrowingDnsService(),
        ports: _ThrowingPortService(),
      );

      final report = await NetworkDiagnostic.diagnose(
        includeSpeedTest: false,
        includePorts: true,
      );

      // 每个失败的子项只是留空，报告本身仍然产出 / Every failing sub-test only
      // leaves its own field empty; the report is still produced.
      expect(report.connection.isConnected, isTrue);
      expect(report.ping, isNull);
      expect(report.dnsResults, isEmpty);
      expect(report.portResults, isEmpty);
      expect(report.speedTest, isNull);
      expect(report.quality.level, NetworkQualityLevel.unknown);
    });

    test('runs the independent probes concurrently', () async {
      final ping = _TrackingPingService();
      final dns = _TrackingDnsService();
      NetworkDiagnostic.configure(
        connectivity: _FakeConnectivityService(),
        ping: ping,
        dns: dns,
      );

      await NetworkDiagnostic.diagnose(includeSpeedTest: false);

      expect(ping.started, isNotNull);
      expect(dns.started, isNotNull);
      // DNS 在 ping 结束**之前**就已开始 —— 串行执行时不可能成立 / DNS started
      // **before** ping ended, which is impossible when they run in sequence.
      expect(dns.started!.isBefore(ping.ended!), isTrue);
    });

    test('collects successful sub-probes into the report', () async {
      NetworkDiagnostic.configure(
        connectivity: _FakeConnectivityService(),
        ping: _FakePingService(),
        dns: _FakeDnsService(),
      );

      final report = await NetworkDiagnostic.diagnose(
        includeSpeedTest: false,
        includePorts: false,
      );

      expect(report.ping, isNotNull);
      expect(report.dnsResults, hasLength(2));
      // 只有成功项计入 DNS 延迟均值：失败的 5 s 不应把 20 ms 拉高 / Only
      // successful results feed the average: the failed 5 s must not inflate it.
      expect(report.quality.metrics['dns'], 20);
      expect(report.quality.level, isNot(NetworkQualityLevel.unknown));
    });
  });
}

/// 固定返回「已连接」的连通性服务 / Connectivity service that is always online.
class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService() : super(adapter: _FakeConnectivityAdapter());

  @override
  Future<NetworkConnectionInfo> checkConnection({
    bool includeNativeDetails = true,
    bool probeReachability = false,
    Duration probeTimeout = const Duration(seconds: 3),
  }) async {
    return NetworkConnectionInfo(
      isConnected: true,
      type: NetworkType.wifi,
      timestamp: DateTime.now(),
    );
  }
}

class _FakeConnectivityAdapter implements ConnectivityAdapter {
  @override
  Future<List<String>> checkConnectivity() async => const <String>['wifi'];

  @override
  Stream<List<String>> get onConnectivityChanged =>
      const Stream<List<String>>.empty();
}

class _ThrowingPingService extends PingService {
  @override
  Future<PingResult> ping({
    required String host,
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 200),
    int? port,
    PingMode mode = PingMode.tcp,
  }) async {
    throw StateError('ping unavailable');
  }
}

class _ThrowingDnsService extends DnsService {
  @override
  Future<List<DnsTestResult>> testDns({
    String domain = 'www.google.com',
    List<String> dnsServers = const <String>[
      '1.1.1.1',
      '8.8.8.8',
      '114.114.114.114',
    ],
    Duration? timeout,
    bool concurrent = true,
    bool includeSystemResolver = false,
  }) async {
    throw StateError('dns unavailable');
  }
}

class _ThrowingPortService extends PortService {
  @override
  Future<List<PortCheckResult>> scanPorts({
    required String host,
    List<int> ports = const <int>[80, 443],
    Duration? timeout,
    int concurrency = 12,
  }) async {
    throw StateError('port scan unavailable');
  }
}

/// 记录执行区间的延迟服务，用于判断是否并发执行 / Latency service that records
/// its execution window so concurrency can be asserted.
class _TrackingPingService extends PingService {
  DateTime? started;
  DateTime? ended;

  @override
  Future<PingResult> ping({
    required String host,
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 200),
    int? port,
    PingMode mode = PingMode.tcp,
  }) async {
    started = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    ended = DateTime.now();
    return PingResult(
      host: host,
      sent: 1,
      received: 1,
      times: const <double>[12],
      timestamp: DateTime.now(),
    );
  }
}

class _TrackingDnsService extends DnsService {
  DateTime? started;

  @override
  Future<List<DnsTestResult>> testDns({
    String domain = 'www.google.com',
    List<String> dnsServers = const <String>[
      '1.1.1.1',
      '8.8.8.8',
      '114.114.114.114',
    ],
    Duration? timeout,
    bool concurrent = true,
    bool includeSystemResolver = false,
  }) async {
    started = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const <DnsTestResult>[];
  }
}

class _FakePingService extends PingService {
  @override
  Future<PingResult> ping({
    required String host,
    int count = 4,
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 200),
    int? port,
    PingMode mode = PingMode.tcp,
  }) async {
    return PingResult(
      host: host,
      sent: 2,
      received: 2,
      times: const <double>[10, 30],
      timestamp: DateTime.now(),
    );
  }
}

/// 一台成功（20 ms）一台失败（5 s）：只有成功项进入均值 / One succeeds at 20 ms
/// and one fails at 5 s; only the success feeds the average.
class _FakeDnsService extends DnsService {
  @override
  Future<List<DnsTestResult>> testDns({
    String domain = 'www.google.com',
    List<String> dnsServers = const <String>[
      '1.1.1.1',
      '8.8.8.8',
      '114.114.114.114',
    ],
    Duration? timeout,
    bool concurrent = true,
    bool includeSystemResolver = false,
  }) async {
    return <DnsTestResult>[
      DnsTestResult(
        server: '1.1.1.1',
        domain: domain,
        isSuccess: true,
        responseTime: const Duration(milliseconds: 20),
        resolvedIps: const <String>['1.1.1.1'],
        timestamp: DateTime.now(),
      ),
      DnsTestResult(
        server: '8.8.8.8',
        domain: domain,
        isSuccess: false,
        responseTime: const Duration(seconds: 5),
        errorMessage: 'timed out',
        timestamp: DateTime.now(),
      ),
    ];
  }
}
