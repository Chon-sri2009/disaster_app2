import 'dart:convert';

import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// Opens every tab of the bottom bar (AppNavBar) and checks its main text appears.
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
    expect(find.byType(AppNavBar), findsOneWidget);
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

  const officialSource = 'ประกาศเตือนภัยทางการ ในพื้นที่ล่าสุดของคุณ';

  // A cached snapshot with one TMD warning over lat 13-14, lng 100-101, stamped just now
  // (the app's real clock is used), plus a phone last seen at [at].
  Future<void> pumpWithTmdWarning(
    WidgetTester tester,
    LatLng at, {
    Map<String, String> headline = const {'th': 'ฝนตกหนัก', 'en': 'Heavy rain'},
    int? skippedFiles,
    bool visible = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final now = DateTime.now().toUtc();
    String iso(Duration d) => now.add(d).toIso8601String();
    final snapshot = jsonEncode({
      'generatedAt': iso(Duration.zero),
      'skippedFiles': ?skippedFiles,
      'alerts': [
        if (visible)
          {
            'id': 'tmd-1',
            'sender': 'TMD',
            'status': 'Actual',
            'msgType': 'Alert',
            'level': 'warning',
            'headline': headline,
            'sent': iso(const Duration(minutes: -10)),
            'expires': iso(const Duration(hours: 3)),
            'polygons': [
              [
                [100.0, 13.0],
                [101.0, 13.0],
                [101.0, 14.0],
                [100.0, 14.0],
              ],
            ],
          },
      ],
      'noPolygon': 0,
    });
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.saveSnapshot(snapshot, now);
    await storage.saveLastPosition(at);
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    await tester.pump();
  }

  testWidgets('Home shows the warning and TMD inside the alert area', (
    tester,
  ) async {
    await pumpWithTmdWarning(tester, LatLng(13.5, 100.5));

    // The level card names the official alert as its source, and the notice shows the issuer.
    expect(find.text(officialSource), findsOneWidget);
    expect(find.text('เตือนภัย'), findsWidgets);
    expect(find.textContaining('TMD'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home level ignores an alert area far from the phone', (
    tester,
  ) async {
    await pumpWithTmdWarning(tester, LatLng(18.8, 98.9));

    // The notice list still shows the alert; the level card must not take its tier.
    expect(find.text(officialSource), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home notices render an alert with no headline', (tester) async {
    await pumpWithTmdWarning(tester, LatLng(13.5, 100.5), headline: {});

    expect(tester.takeException(), isNull);
    // The level label stands in for the missing headline text.
    expect(find.text('เตือนภัย'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('skipped files show the stale banner, not "No alerts"', (
    tester,
  ) async {
    await pumpWithTmdWarning(
      tester,
      LatLng(13.5, 100.5),
      skippedFiles: 2,
      visible: false,
    );

    expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);
    expect(find.textContaining('ไม่มีประกาศเตือนภัยในพื้นที่'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
