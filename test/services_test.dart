import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/zero_network_kit.dart';
import 'package:zero_network_kit/advanced.dart';

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
