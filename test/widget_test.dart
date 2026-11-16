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
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    // The loading screen gives way to the app once the map has failed to open.
    await tester.pump();

    expect(find.text('SOS'), findsOneWidget);

    // Thai is the default language.
    await tester.tap(find.text('เซนเซอร์'));
    await tester.pump();
    expect(find.text('ทดลอง: จำลองระดับน้ำ'), findsOneWidget);

    await tester.tap(find.text('แผนที่'));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('รายงาน'));
    await tester.pump();
    expect(find.text('แจ้งความเสียหาย'), findsOneWidget);

    await tester.tap(find.text('คู่มือ'));
    await tester.pump();
    expect(find.text('คู่มือออฟไลน์'), findsOneWidget);

    // Remove the app so the sensor timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the language button switches the whole UI to English', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    // The loading screen gives way to the app once the map has failed to open.
    await tester.pump();

    await tester.tap(find.text('คู่มือ'));
    await tester.pump();
    await tester.tap(find.text('English'));
    await tester.pump();

    expect(find.text('Offline guide'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(storage.language.code, 'en');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home shows no invented warning when no alert data exists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    // The loading screen gives way to the app once the map has failed to open.
    await tester.pump();

    expect(
      find.textContaining('ยังไม่ได้เชื่อมต่อประกาศเตือนภัยทางการ'),
      findsOneWidget,
    );
    expect(find.textContaining('Heavy rain'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
