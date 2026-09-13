import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_network_kit_example/main.dart';

void main() {
  testWidgets('renders the diagnostic dashboard', (tester) async {
    // 放大测试视口，让懒加载的 ListView 构建出全部卡片 /
    // Enlarge the viewport so the lazy ListView builds every card.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ZeroNetworkKitExampleApp());
    await tester.pump();

    expect(find.text('Zero Network Kit'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Ping'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.text('Speed test'), findsOneWidget);
    expect(find.text('Quality score'), findsOneWidget);
    expect(find.text('Full diagnostic'), findsOneWidget);
    expect(find.text('Benchmark the API'), findsOneWidget);
    expect(find.text('Run'), findsWidgets);
  });
}
