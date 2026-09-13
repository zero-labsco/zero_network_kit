// 集成测试在真实设备/模拟器上运行，可以访问原生通道与真实网络 /
// Integration tests run on a real device or simulator, so they can exercise the
// platform channel and the real network stack.
//
// 运行方式 / Run with:
//   flutter test integration_test -d <device-id>
//
// 说明：集成测试依赖外网连通性，在无网络环境下会失败，因此 CI 默认不执行 /
// Note: these tests require internet access, so they are not part of the default
// CI pipeline.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zero_network_kit/zero_network_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(ZeroNetworkKit.dispose);

  testWidgets('getPlatformVersion returns a non-empty string', (tester) async {
    final version = await ZeroNetworkKit.getPlatformVersion();
    expect(version, isNotNull);
    expect(version!.isNotEmpty, isTrue);
  });

  testWidgets('getNativeNetworkDetails answers with a map', (tester) async {
    final details = await ZeroNetworkKit.getNativeNetworkDetails();
    expect(details, isNotNull);
  });

  testWidgets('checkConnection reports an active transport', (tester) async {
    final info = await NetworkDiagnostic.checkConnection();

    expect(info.isConnected, isTrue);
    expect(info.type, isNot(NetworkType.none));
    expect(info.ipAddress, isNotNull);
  });

  testWidgets('ping reaches a public resolver', (tester) async {
    final result = await NetworkDiagnostic.ping(count: 3);

    expect(result.sent, 3);
    expect(result.isSuccess, isTrue);
    expect(result.averageTime, greaterThan(0));
  });

  testWidgets('dns resolves a well known domain', (tester) async {
    final results = await NetworkDiagnostic.resolve(
      domain: 'example.com',
      dnsServers: const <String>['1.1.1.1'],
    );

    expect(results, hasLength(1));
    expect(results.single.isSuccess, isTrue);
    expect(results.single.resolvedIps, isNotEmpty);
  });

  testWidgets('port check detects an open and a closed port', (tester) async {
    expect(
      await NetworkDiagnostic.isPortOpen(host: '1.1.1.1', port: 443),
      isTrue,
    );
    expect(
      await NetworkDiagnostic.isPortOpen(host: '1.1.1.1', port: 9),
      isFalse,
    );
  });

  testWidgets('full diagnostic aggregates a report', (tester) async {
    final report = await NetworkDiagnostic.diagnose(
      includeSpeedTest: false,
      includePorts: true,
    );

    expect(report.connection.isConnected, isTrue);
    expect(report.ping, isNotNull);
    expect(report.dnsResults, isNotEmpty);
    expect(report.quality.score, greaterThan(0));
  });
}
