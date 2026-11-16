import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// Opens every tab of the NavigationBar and checks its main text appears.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    mockPathProvider();
  });

  testWidgets('all five screens are reachable', (tester) async {
    // A phone-sized portrait screen shows the bottom NavigationBar (wider screens get a rail).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: neverLoadMap),
    );

    expect(find.text('SOS'), findsOneWidget);

    await tester.tap(find.text('Sensors'));
    await tester.pump();
    expect(find.text('Demo: simulate water level'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pump();
    expect(find.text('Report damage'), findsOneWidget);

    await tester.tap(find.text('Guide'));
    await tester.pump();
    expect(find.text('Offline guide'), findsOneWidget);

    // Remove the app so the sensor timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
