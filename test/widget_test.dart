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

  testWidgets('all five tabs are reachable', (tester) async {
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
    await tester.tap(find.text('โทร'));
    await tester.pump();
    expect(find.text('โทรฉุกเฉิน'), findsOneWidget);
    expect(find.text('1669'), findsOneWidget);

    await tester.tap(find.text('แผนที่'));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    // Sensor readings live in the map's sheet, behind the Sensors switch.
    await tester.tap(find.text('เซนเซอร์'));
    await tester.pump();
    expect(find.text('ระดับน้ำ'), findsOneWidget);
    expect(find.text('ทดลอง: จำลองระดับน้ำ'), findsOneWidget);

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

    // The language lives in Settings, behind the gear on every tab.
    await tester.tap(find.byTooltip('ตั้งค่า').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guide'));
    await tester.pump();
    expect(find.text('Offline guide'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(storage.language.code, 'en');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings can force the night board and keep it', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    await tester.pump();

    BuildContext home() => tester.element(find.text('หน้าแรก').first);
    expect(Theme.of(home()).brightness, Brightness.light);

    await tester.tap(find.byTooltip('ตั้งค่า').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('มืด'));
    await tester.pumpAndSettle();
    // pageBack() looks for the English "Back" tooltip; this UI is Thai.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(Theme.of(home()).brightness, Brightness.dark);
    expect(storage.themeMode, ThemeMode.dark);

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
