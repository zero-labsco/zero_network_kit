import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit/zero_network_kit_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelZeroNetworkKit();
  const channel = MethodChannel('zero_network_kit');

  void mockHandler(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion returns the native string', () async {
    mockHandler((call) async {
      expect(call.method, 'getPlatformVersion');
      return '42';
    });

    expect(await platform.getPlatformVersion(), '42');
  });

  test('getNetworkDetails returns a string keyed map', () async {
    mockHandler((call) async {
      expect(call.method, 'getNetworkDetails');
      return <Object?, Object?>{
        'ipAddress': '192.168.1.20',
        'signalStrength': -52,
        'isVpn': true,
      };
    });

    final details = await platform.getNetworkDetails();

    expect(details, isNotNull);
    expect(details!['ipAddress'], '192.168.1.20');
    expect(details['signalStrength'], -52);
    expect(details['isVpn'], isTrue);
  });

  test('getNetworkDetails maps a null reply to null', () async {
    mockHandler((call) async => null);

    expect(await platform.getNetworkDetails(), isNull);
  });
}
