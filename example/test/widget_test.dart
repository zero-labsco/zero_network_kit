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

  testWidgets('renders the full diagnostic dashboard', (tester) async {
    // Give the ListView a tall viewport so every probe card is built and
    // asserted (ListView builds children lazily, below the fold by default).
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(const ZeroNetworkKitExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Zero Network Kit'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Run'), findsWidgets);

    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Ping'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.text('Speed test'), findsOneWidget);
    expect(find.text('Quality score'), findsOneWidget);
    expect(find.text('Full diagnostic'), findsOneWidget);
    expect(find.text('Benchmark the API'), findsOneWidget);
  });

  testWidgets('shows the platform version once resolved', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;

    await tester.pumpWidget(const ZeroNetworkKitExampleApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('platform:'), findsOneWidget);
  });
}
