import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The example app resolves the platform version through the `zero_network_kit`
  // method channel. Stub it so the dashboard builds deterministically in a
  // headless test environment where no native side is attached.
  const channel = MethodChannel('zero_network_kit');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getPlatformVersion') return 'Test';
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('renders the dashboard sections and actions', (tester) async {
    // Give the ListView a tall viewport so every section is built and asserted
    // (ListView builds children lazily, below the fold by default).
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(const ZeroNetworkKitExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('zero_network_kit'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Full diagnostic'),
      findsOneWidget,
    );

    // 端口扫描在 Web 上不可用，故不在断言里固定要求 / Port scanning is unavailable
    // on the web, so it is not asserted unconditionally.
    for (final label in <String>[
      'Connection',
      'Ping',
      'DNS',
      'Speed',
      'Quality',
      'Benchmark',
      'Watch',
    ]) {
      expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
    }
  });

  testWidgets('shows the platform version once resolved', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(const ZeroNetworkKitExampleApp());
    await tester.pumpAndSettle();

    // The stubbed channel reports "Test"; it lands in the `platform` row.
    expect(find.text('Test'), findsOneWidget);
  });
}
