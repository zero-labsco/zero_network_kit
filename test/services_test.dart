import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zero_network_kit/zero_network_kit.dart';
import 'package:zero_network_kit/advanced.dart';

/// 原始平台实例，测试替换后用于恢复 / The original platform instance, used to
/// restore state after a test replaces it.
final ZeroNetworkKitPlatform _initialPlatform = ZeroNetworkKitPlatform.instance;

/// 返回完整原生详情（含 BSSID / DNS）的假平台实现 / Fake platform returning the
/// full native detail set, including BSSID and DNS server.
class _FakeNativeDetailsPlatform
    with MockPlatformInterfaceMixin
    implements ZeroNetworkKitPlatform {
  @override
  Future<String?> getPlatformVersion() async => 'fake';

  @override
  Future<Map<String, Object?>?> getNetworkDetails() async => <String, Object?>{
    'ipAddress': '192.168.1.10',
    'gateway': '192.168.1.1',
    'ssid': 'zero-labs',
    'bssid': 'aa:bb:cc:dd:ee:ff',
    'dnsServer': '192.168.1.1',
    'signalStrength': -55,
    'isVpn': false,
  };
}

/// 可控的连通性数据源 / A controllable connectivity source.
class FakeConnectivityAdapter implements ConnectivityAdapter {
  FakeConnectivityAdapter(this._results);

  List<String> _results;
  final StreamController<List<String>> _controller =
      StreamController<List<String>>.broadcast();

  @override
  Future<List<String>> checkConnectivity() async => _results;

  @override
  Stream<List<String>> get onConnectivityChanged => _controller.stream;

  void emit(List<String> results) {
    _results = results;
    _controller.add(results);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  group('ConnectivityService', () {
    test('maps adapter transports into a connection snapshot', () async {
      final adapter = FakeConnectivityAdapter(<String>['wifi']);
      addTearDown(adapter.dispose);

      final info = await ConnectivityService(
        adapter: adapter,
      ).checkConnection(includeNativeDetails: false);

      expect(info.isConnected, isTrue);
      expect(info.type, NetworkType.wifi);
      expect(info.timestamp, isNotNull);
    });

    test('reports no network when the adapter has none', () async {
      final adapter = FakeConnectivityAdapter(<String>['none']);
      addTearDown(adapter.dispose);

      final info = await ConnectivityService(
        adapter: adapter,
      ).checkConnection(includeNativeDetails: false);

      expect(info.type, NetworkType.none);
    });

    test('degrades gracefully when the adapter throws', () async {
      final info = await ConnectivityService(
        adapter: _ThrowingAdapter(),
      ).checkConnection(includeNativeDetails: false);

      expect(info, isNotNull);
      expect(info.isVpn, isFalse);
    });

    test('emits an initial snapshot then reacts to changes', () async {
      final adapter = FakeConnectivityAdapter(<String>['wifi']);
      addTearDown(adapter.dispose);
      final service = ConnectivityService(adapter: adapter);

      final collected = service.onConnectivityChanged
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 5));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      adapter.emit(<String>['mobile']);

      final emitted = await collected;
      expect(emitted.first.type, NetworkType.wifi);
      expect(emitted.last.type, NetworkType.mobile);
    });

    test('honours the reachability probe', () async {
      final adapter = FakeConnectivityAdapter(<String>['ethernet']);
      addTearDown(adapter.dispose);
      final service = ConnectivityService(adapter: adapter)
        ..reachabilityProbe = () async => true;

      final info = await service.checkConnection(
        includeNativeDetails: false,
        probeReachability: true,
      );

      expect(info.isReachable, isTrue);
    });

    test('trusts an explicit "none" over any local address', () async {
      final adapter = FakeConnectivityAdapter(<String>['none']);
      addTearDown(adapter.dispose);

      final info = await ConnectivityService(
        adapter: adapter,
      ).checkConnection(includeNativeDetails: false);

      // 适配器已明确报告 `none`；虚拟机网卡 / Docker 网桥残留的 IP 不应把离线判
      // 成在线 / The adapter explicitly reported `none`; a leftover VM or Docker
      // bridge IP must not make an offline device look online.
      expect(info.type, NetworkType.none);
      expect(info.isConnected, isFalse);
    });

    test('caches the change stream across reads', () {
      final adapter = FakeConnectivityAdapter(<String>['wifi']);
      addTearDown(adapter.dispose);
      final service = ConnectivityService(adapter: adapter);

      // 此前每次读取 getter 都会新建一个流，多个订阅者会各自重复采集一轮 /
      // Reading the getter used to build a fresh stream, so N subscribers each
      // ran a full sampling round.
      expect(
        service.onConnectivityChanged,
        same(service.onConnectivityChanged),
      );
    });

    test('surfaces bssid and dnsServer from the native details', () async {
      // 这两个键由 Android / Windows 原生层产出，此前从未被 Dart 侧消费 /
      // Both keys are produced by the Android / Windows native layers and used
      // to be dropped by the Dart side.
      ZeroNetworkKitPlatform.instance = _FakeNativeDetailsPlatform();
      addTearDown(() {
        ZeroNetworkKitPlatform.instance = _initialPlatform;
      });

      final info = await ConnectivityService(
        adapter: FakeConnectivityAdapter(<String>['wifi']),
      ).checkConnection();

      expect(info.bssid, 'aa:bb:cc:dd:ee:ff');
      expect(info.dnsServer, '192.168.1.1');
      expect(info.ssid, 'zero-labs');
    });
  });

  group('PingService', () {
    test('measures a reachable loopback port', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      final result = await const PingService().ping(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        count: 3,
        interval: Duration.zero,
        timeout: const Duration(seconds: 2),
      );

      expect(result.sent, 3);
      expect(result.received, 3);
      expect(result.packetLoss, 0);
      expect(result.averageTime, greaterThan(0));
      expect(result.isSuccess, isTrue);
    });

    test('reports 100% loss for a closed port', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = probe.port;
      await probe.close();

      final result = await const PingService().ping(
        host: InternetAddress.loopbackIPv4.address,
        port: closedPort,
        count: 2,
        interval: Duration.zero,
        timeout: const Duration(milliseconds: 300),
      );

      expect(result.received, 0);
      expect(result.packetLoss, 100);
      expect(result.isSuccess, isFalse);
    });

    test('returns an empty result for a non positive count', () async {
      final result = await const PingService().ping(
        host: '127.0.0.1',
        count: 0,
      );

      expect(result.sent, 0);
      expect(result.received, 0);
    });

    test('builds platform specific ICMP arguments', () {
      // `-W` 的单位在 macOS (BSD) 上是**毫秒**、在 Linux iputils 上是**秒**，
      // Windows 的 `-w` 也是毫秒 / `-W` is **milliseconds** on macOS (BSD) and
      // **seconds** on Linux iputils; Windows `-w` is milliseconds too.
      expect(
        PingService.icmpArgs(
          host: '1.1.1.1',
          count: 3,
          timeout: const Duration(seconds: 2),
          isWindows: false,
          isMacOS: true,
        ),
        <String>['-c', '3', '-W', '2000', '1.1.1.1'],
        reason: 'macOS -W takes milliseconds',
      );

      expect(
        PingService.icmpArgs(
          host: '1.1.1.1',
          count: 3,
          timeout: const Duration(seconds: 2),
          isWindows: false,
          isMacOS: false,
        ),
        <String>['-c', '3', '-W', '2', '1.1.1.1'],
        reason: 'Linux -W takes whole seconds',
      );

      expect(
        PingService.icmpArgs(
          host: '1.1.1.1',
          count: 3,
          timeout: const Duration(seconds: 2),
          isWindows: true,
          isMacOS: false,
        ),
        <String>['-n', '3', '-w', '2000', '1.1.1.1'],
        reason: 'Windows -w takes milliseconds',
      );

      // 不足 1 秒的超时在 Linux 上仍需 ≥ 1，否则 ping 会直接拒绝 /
      // A sub-second timeout still has to be ≥ 1 on Linux.
      expect(
        PingService.icmpArgs(
          host: '1.1.1.1',
          count: 1,
          timeout: const Duration(milliseconds: 200),
          isWindows: false,
          isMacOS: false,
        ),
        <String>['-c', '1', '-W', '1', '1.1.1.1'],
      );
    });
  });

  group('DnsService', () {
    test('clamps the A/AAAA sibling grace window', () {
      // 丢包的 AAAA 不能把整次解析拖到超时上限：宽限窗口取超时的五分之一并夹在
      // 100 ms – 1 s / A dropped AAAA must not stretch the lookup to the full
      // timeout: the grace window is a fifth of it, clamped to 100 ms – 1 s.
      expect(
        DnsService.siblingGrace(const Duration(seconds: 5)),
        const Duration(seconds: 1),
      );
      expect(
        DnsService.siblingGrace(const Duration(milliseconds: 250)),
        const Duration(milliseconds: 100),
      );
      expect(
        DnsService.siblingGrace(const Duration(seconds: 2)),
        const Duration(milliseconds: 400),
      );
    });
  });

  group('PortService', () {
    test('detects an open port and a closed port', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      const service = PortService();

      final open = await service.checkPort(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      expect(open.isOpen, isTrue);
      expect(open.errorMessage, isNull);

      final closedPort = await _freePort();
      final closed = await service.checkPort(
        host: InternetAddress.loopbackIPv4.address,
        port: closedPort,
        timeout: const Duration(milliseconds: 300),
      );
      expect(closed.isOpen, isFalse);
      expect(closed.errorMessage, isNotNull);
    });

    test('scans ports preserving the requested order', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final closedPort = await _freePort();

      final results = await const PortService().scanPorts(
        host: InternetAddress.loopbackIPv4.address,
        ports: <int>[closedPort, server.port],
        timeout: const Duration(milliseconds: 300),
      );

      expect(results, hasLength(2));
      expect(results.first.port, closedPort);
      expect(results.first.isOpen, isFalse);
      expect(results.last.port, server.port);
      expect(results.last.isOpen, isTrue);
    });

    test('returns an empty list for an empty port list', () async {
      expect(
        await const PortService().scanPorts(host: '127.0.0.1', ports: <int>[]),
        isEmpty,
      );
    });
  });

  group('BenchmarkService', () {
    test('collects samples, counts failures and skips warm-up', () async {
      var calls = 0;
      final result = await const BenchmarkService().run(
        testName: 'unit',
        iterations: 4,
        warmupIterations: 2,
        task: (_) async {
          calls += 1;
          if (calls == 6) throw StateError('boom');
        },
      );

      expect(calls, 6, reason: '2 warm-up + 4 measured iterations');
      expect(result.iterations, 3);
      expect(result.failures, 1);
      expect(result.operationsPerSecond, greaterThan(0));
    });

    test('runSuite returns one result per task', () async {
      final suite = await const BenchmarkService().runSuite(
        suiteName: 'smoke',
        iterations: 2,
        warmupIterations: 0,
        tasks: <String, Future<void> Function(int)>{
          'a': (_) async {},
          'b': (_) async {},
        },
      );

      expect(suite.suiteName, 'smoke');
      expect(suite.results.map((result) => result.testName), <String>[
        'a',
        'b',
      ]);
    });
  });

  group('QualityService', () {
    test(
      'falls back to the speed-test latency when no ping was requested',
      () async {
        final speedTest = _FakeSpeedTestService();
        final service = QualityService(
          connectivityService: _StaticConnectivityService(),
          speedTestService: speedTest,
        );

        final score = await service.evaluateQuality(
          config: const NetworkDiagnosticConfig(),
          includePing: false,
          includeDns: false,
          includeSpeedTest: true,
        );

        // 未单独跑延迟探测时，测速必须自己带上一次探测，否则 `speed.ping` 恒为 0、
        // 回退永远取不到值（此前它是一段死代码）/ With no standalone ping the speed
        // test must run the probe itself; otherwise `speed.ping` stays 0 and the
        // fallback can never fire (it used to be dead code).
        expect(speedTest.includePingSeen, isTrue);
        expect(score.metrics['latency'], 25);
      },
    );

    test(
      'does not repeat the probe when a standalone ping already ran',
      () async {
        final speedTest = _FakeSpeedTestService();
        final service = QualityService(
          connectivityService: _StaticConnectivityService(),
          speedTestService: speedTest,
        );

        await service.evaluateQuality(
          config: const NetworkDiagnosticConfig(),
          includePing: false,
          includeDns: false,
          includeSpeedTest: true,
        );

        // 单独跑过 ping 之后，测速不该再重复一次探测 / Once a standalone ping ran,
        // the speed test must not probe again.
        expect(speedTest.includePingSeen, isTrue);

        final second = _FakeSpeedTestService();
        await QualityService(
          connectivityService: _StaticConnectivityService(),
          pingService: _FakePingService(),
          speedTestService: second,
        ).evaluateQuality(
          config: const NetworkDiagnosticConfig(),
          includePing: true,
          includeDns: false,
          includeSpeedTest: true,
        );
        expect(second.includePingSeen, isFalse);
      },
    );
  });
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _ThrowingAdapter implements ConnectivityAdapter {
  @override
  Future<List<String>> checkConnectivity() async =>
      throw const SocketException('adapter unavailable');

  @override
  Stream<List<String>> get onConnectivityChanged =>
      const Stream<List<String>>.empty();
}

/// 固定返回「已连接」的连通性服务，避免测试访问真实平台通道 / Connectivity
/// service that is always online so tests never touch a real platform channel.
class _StaticConnectivityService extends ConnectivityService {
  _StaticConnectivityService()
    : super(adapter: FakeConnectivityAdapter(<String>['wifi']));

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

/// 记录 `includePing` 并返回固定速率与延迟的测速服务 / Speed-test service that
/// records `includePing` and returns a fixed throughput and latency.
class _FakeSpeedTestService extends SpeedTestService {
  bool? includePingSeen;

  @override
  Future<SpeedTestResult> runSpeedTest({
    String downloadUrl = 'https://speed.cloudflare.com/__down?bytes=25000000',
    String? uploadUrl,
    Duration timeout = const Duration(seconds: 30),
    Duration maxDuration = const Duration(seconds: 10),
    Duration pingTimeout = const Duration(seconds: 3),
    int uploadPayloadBytes = 1048576,
    String? pingHost,
    int pingCount = 4,
    bool includeUpload = true,
    bool includePing = true,
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    includePingSeen = includePing;
    return SpeedTestResult(
      downloadSpeed: 80,
      uploadSpeed: 20,
      ping: 25,
      jitter: 4,
      timestamp: DateTime.now(),
    );
  }
}

/// 恒定成功的延迟服务，避免测试发起真实网络请求 / Latency service that always
/// succeeds, so tests never hit the network.
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
      sent: count,
      received: count,
      times: const <double>[10],
      timestamp: DateTime.now(),
    );
  }
}
