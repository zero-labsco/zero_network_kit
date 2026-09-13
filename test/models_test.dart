import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  group('NetworkType', () {
    test('parses adapter strings', () {
      expect(NetworkType.fromRaw('wifi'), NetworkType.wifi);
      expect(NetworkType.fromRaw('Wi-Fi'), NetworkType.wifi);
      expect(NetworkType.fromRaw('mobile'), NetworkType.mobile);
      expect(
        NetworkType.fromRaw('ConnectivityResult.ethernet'),
        NetworkType.ethernet,
      );
      expect(NetworkType.fromRaw('bluetooth'), NetworkType.bluetooth);
      expect(NetworkType.fromRaw('vpn'), NetworkType.vpn);
      expect(NetworkType.fromRaw('none'), NetworkType.none);
      expect(NetworkType.fromRaw(''), NetworkType.none);
      expect(NetworkType.fromRaw(null), NetworkType.none);
      expect(NetworkType.fromRaw('carrier-pigeon'), NetworkType.other);
    });

    test('exposes id / label / isConnected', () {
      expect(NetworkType.wifi.id, 'wifi');
      expect(NetworkType.wifi.label, 'Wi-Fi');
      expect(NetworkType.none.isConnected, isFalse);
      expect(NetworkType.ethernet.isConnected, isTrue);
    });
  });

  group('NetworkConnectionInfo', () {
    test('round trips through toMap/fromMap', () {
      final info = NetworkConnectionInfo(
        isConnected: true,
        type: NetworkType.wifi,
        ssid: 'zero-labs',
        signalStrength: -48,
        ipAddress: '192.168.1.20',
        ipv6Address: 'fe80::1',
        gateway: '192.168.1.1',
        macAddress: 'aa:bb:cc:dd:ee:ff',
        isVpn: true,
        isReachable: true,
        timestamp: DateTime.parse('2026-01-02T03:04:05.000Z'),
      );

      final restored = NetworkConnectionInfo.fromMap(info.toMap());

      expect(restored, info);
      expect(restored.hashCode, info.hashCode);
    });

    test('copyWith keeps untouched fields', () {
      final info = NetworkConnectionInfo(
        isConnected: true,
        type: NetworkType.mobile,
        timestamp: DateTime.parse('2026-01-02T03:04:05.000Z'),
      );

      final probed = info.copyWith(isReachable: false);

      expect(probed.isReachable, isFalse);
      expect(probed.type, info.type);
      expect(probed.timestamp, info.timestamp);
    });
  });

  group('PingResult', () {
    test('computes statistics from the samples', () {
      final result = PingResult(
        host: '1.1.1.1',
        sent: 4,
        received: 3,
        times: <double>[10, 20, 30],
        timestamp: DateTime.now(),
      );

      expect(result.lost, 1);
      expect(result.packetLoss, 25);
      expect(result.minTime, 10);
      expect(result.maxTime, 30);
      expect(result.averageTime, 20);
      expect(result.jitter, 10);
      expect(result.isSuccess, isTrue);
    });

    test('handles a total loss without dividing by zero', () {
      final result = PingResult(
        host: 'unreachable.invalid',
        sent: 4,
        received: 0,
        times: const <double>[],
        timestamp: DateTime.now(),
      );

      expect(result.packetLoss, 100);
      expect(result.averageTime, 0);
      expect(result.jitter, 0);
      expect(result.isSuccess, isFalse);
    });
  });

  group('SpeedTestResult', () {
    test('converts bytes and elapsed time into Mbps', () {
      expect(
        SpeedTestResult.mbpsFromBytes(1250000, const Duration(seconds: 1)),
        closeTo(10, 0.001),
      );
      expect(
        SpeedTestResult.mbpsFromBytes(1000, Duration.zero),
        0,
        reason: 'guards against a zero duration',
      );
    });
  });

  group('BenchmarkResult', () {
    test('derives mean/min/max/deviation/throughput from samples', () {
      final result = BenchmarkResult.fromSamples(
        testName: 'ping',
        samples: const <int>[1000, 2000, 3000, 4000],
        totalDuration: const Duration(milliseconds: 10),
        timestamp: DateTime.now(),
        failures: 1,
      );

      expect(result.iterations, 4);
      expect(result.averageDuration, const Duration(microseconds: 2500));
      expect(result.minDuration, const Duration(microseconds: 1000));
      expect(result.maxDuration, const Duration(microseconds: 4000));
      expect(result.standardDeviation.inMicroseconds, closeTo(1118, 1));
      expect(result.operationsPerSecond, closeTo(400, 0.001));
      expect(result.failures, 1);
    });

    test('handles an empty sample set', () {
      final result = BenchmarkResult.fromSamples(
        testName: 'dns',
        samples: const <int>[],
        totalDuration: const Duration(milliseconds: 3),
        timestamp: DateTime.now(),
      );

      expect(result.iterations, 0);
      expect(result.averageDuration, Duration.zero);
      expect(result.operationsPerSecond, 0);
    });

    test('suite lookup finds results by name', () {
      final suite = BenchmarkSuiteResult(
        suiteName: 'network',
        results: <BenchmarkResult>[
          BenchmarkResult.fromSamples(
            testName: 'ping',
            samples: const <int>[1000],
            totalDuration: const Duration(milliseconds: 1),
            timestamp: DateTime.now(),
          ),
        ],
        totalDuration: const Duration(milliseconds: 1),
        timestamp: DateTime.now(),
      );

      expect(suite['ping'], isNotNull);
      expect(suite['missing'], isNull);
      expect(suite.toMap()['suiteName'], 'network');
    });
  });

  group('PortCheckResult / DnsTestResult', () {
    test('expose millisecond helpers', () {
      final port = PortCheckResult(
        host: 'example.com',
        port: 443,
        isOpen: true,
        responseTime: const Duration(microseconds: 1500),
        timestamp: DateTime.now(),
      );
      expect(port.responseTimeMs, closeTo(1.5, 0.0001));

      final dns = DnsTestResult(
        server: '1.1.1.1',
        domain: 'example.com',
        isSuccess: true,
        responseTime: const Duration(microseconds: 2000),
        resolvedIps: const <String>['93.184.216.34'],
        timestamp: DateTime.now(),
      );
      expect(dns.responseTimeMs, closeTo(2, 0.0001));
      expect(dns.primaryAddress, '93.184.216.34');
    });
  });
}
