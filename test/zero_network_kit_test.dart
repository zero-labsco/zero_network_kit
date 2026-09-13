import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:zero_network_kit/zero_network_kit.dart';
import 'package:zero_network_kit/advanced.dart';
import 'package:zero_network_kit/zero_network_kit_method_channel.dart';

class MockZeroNetworkKitPlatform
    with MockPlatformInterfaceMixin
    implements ZeroNetworkKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future<String?>.value('42');

  @override
  Future<Map<String, Object?>?> getNetworkDetails() =>
      Future<Map<String, Object?>?>.value(<String, Object?>{
        'ipAddress': '10.0.0.8',
        'gateway': '10.0.0.1',
        'ssid': 'zero-labs',
        'signalStrength': -55,
        'isVpn': false,
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ZeroNetworkKitPlatform initialPlatform =
      ZeroNetworkKitPlatform.instance;

  tearDown(() {
    ZeroNetworkKitPlatform.instance = initialPlatform;
    NetworkDiagnostic.reset();
  });

  test('MethodChannelZeroNetworkKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZeroNetworkKit>());
  });

  test('getPlatformVersion proxies through the platform interface', () async {
    ZeroNetworkKitPlatform.instance = MockZeroNetworkKitPlatform();

    expect(await ZeroNetworkKit.getPlatformVersion(), '42');
    expect(await NetworkDiagnostic.getPlatformVersion(), '42');
  });

  test(
    'getNativeNetworkDetails proxies through the platform interface',
    () async {
      ZeroNetworkKitPlatform.instance = MockZeroNetworkKitPlatform();

      final details = await ZeroNetworkKit.getNativeNetworkDetails();
      expect(details, isNotNull);
      expect(details!['ipAddress'], '10.0.0.8');
      expect(details['ssid'], 'zero-labs');
    },
  );

  test('init applies the global configuration', () async {
    ZeroNetworkKit.init(
      config: const NetworkDiagnosticConfig(pingHost: '8.8.8.8', pingCount: 7),
    );

    expect(ZeroNetworkKit.isInitialized, isTrue);
    expect(ZeroNetworkKit.config.pingHost, '8.8.8.8');
    expect(NetworkDiagnostic.config.pingCount, 7);

    await ZeroNetworkKit.dispose();

    expect(ZeroNetworkKit.isInitialized, isFalse);
    expect(ZeroNetworkKit.config.pingHost, '1.1.1.1');
  });

  test('configure replaces individual services', () {
    final ping = FakePingService();
    NetworkDiagnostic.configure(ping: ping);

    expect(NetworkDiagnostic.pingService, same(ping));
    expect(NetworkDiagnostic.qualityService.ping, same(ping));
  });
}

/// 仅用于验证服务注入的假实现 / Fake implementation used to verify injection.
class FakePingService extends PingService {
  const FakePingService();
}
