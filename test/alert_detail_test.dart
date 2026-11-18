import 'dart:convert';

import 'package:disaster_app2/l10n/l10n.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/screens/alert_detail_screen.dart';
import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/province_locator.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

final _fixture = ProvinceBoundaries.parse(
  jsonEncode({
    'provinces': [
      {
        'code': 'TH-10',
        'nameTh': 'กรุงเทพมหานคร',
        'nameEn': 'Bangkok',
        'rings': [
          [
            [100.0, 13.0],
            [101.0, 13.0],
            [101.0, 14.0],
            [100.0, 14.0],
          ],
        ],
      },
    ],
  }),
);

OfficialAlert _alert({
  Map<String, String> headline = const {'th': 'ฝนตกหนัก', 'en': 'Heavy rain'},
  DateTime? sent,
  DateTime? expires,
  List<String> codes = const [],
  List<List<LatLng>> polygons = const [],
}) => OfficialAlert(
  id: 'a',
  sender: 'TMD',
  status: 'Actual',
  msgType: 'Alert',
  level: AlertLevel.warning,
  headline: headline,
  sent: sent ?? DateTime.now().toUtc().subtract(const Duration(hours: 1)),
  expires: expires,
  areaCodes: codes,
  polygons: polygons,
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  Future<void> Function() cleanup = () async {};
  void detailTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await cleanup();
    });
  }

  Widget app(Widget home, {String lang = 'th'}) => MaterialApp(
    theme: AppTheme.light(),
    locale: Locale(lang),
    supportedLocales: const [Locale('th'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );

  Future<AlertService> service({DateTime? generated}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final at = generated ?? DateTime.now().toUtc();
    await storage.saveSnapshot(
      jsonEncode({'generatedAt': at.toIso8601String(), 'alerts': []}),
      at,
    );
    final s = AlertService(storage);
    cleanup = () async {
      s.dispose();
    };
    return s;
  }

  Future<void> pump(
    WidgetTester tester,
    OfficialAlert alert, {
    ProvinceBoundaries? provinces,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    String lang = 'th',
    DateTime? generated,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final s = await service(generated: generated);
    await tester.pumpWidget(
      app(
        AlertDetailScreen(alert: alert, alerts: s, provinces: provinces),
        lang: lang,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  String stampOf(WidgetTester tester, DateTime t) =>
      tester.element(find.byType(AlertDetailScreen)).stamp(t);

  detailTest('alert with expiry shows it, not the no-expiry label', (
    tester,
  ) async {
    final exp = DateTime.now().toUtc().add(const Duration(hours: 3));
    await pump(tester, _alert(expires: exp));
    expect(find.text('หมดอายุ'), findsOneWidget);
    expect(find.text(stampOf(tester, exp)), findsOneWidget);
    expect(find.textContaining('ไม่ระบุเวลาหมดอายุ'), findsNothing);
    expect(find.text('เตือนภัย'), findsOneWidget);
    expect(find.text('TMD'), findsOneWidget);
  });

  detailTest('alert without expiry says so and shows the computed end', (
    tester,
  ) async {
    final a = _alert();
    await pump(tester, a);
    expect(
      find.textContaining('ไม่ระบุเวลาหมดอายุ (แสดง 6 ชั่วโมง)'),
      findsOneWidget,
    );
    expect(
      find.textContaining(stampOf(tester, a.effectiveExpiry)),
      findsWidgets,
    );
  });

  detailTest('known province shows Thai then English; unknown shows the code', (
    tester,
  ) async {
    await pump(tester, _alert(codes: ['TH-10', 'TH-99']), provinces: _fixture);
    expect(find.text('กรุงเทพมหานคร · Bangkok'), findsOneWidget);
    expect(find.text('TH-99'), findsOneWidget);
  });

  detailTest('codes without a boundary bundle show the raw code', (
    tester,
  ) async {
    await pump(tester, _alert(codes: ['TH-10']));
    expect(find.text('TH-10'), findsOneWidget);
  });

  detailTest('polygon-only alert says the area is on the map', (tester) async {
    await pump(
      tester,
      _alert(
        polygons: [
          [LatLng(13, 100), LatLng(13, 101), LatLng(14, 101)],
        ],
      ),
    );
    expect(find.text('พื้นที่แสดงบนแผนที่'), findsOneWidget);
  });

  detailTest('no codes and no polygons: area not given', (tester) async {
    await pump(tester, _alert());
    expect(find.text('ไม่ระบุพื้นที่'), findsOneWidget);
  });

  detailTest('both languages: current first, the other shown as given', (
    tester,
  ) async {
    await pump(tester, _alert());
    expect(find.text('ฝนตกหนัก'), findsOneWidget);
    expect(find.text('Heavy rain'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('ฝนตกหนัก')).dy,
      lessThan(tester.getTopLeft(find.text('Heavy rain')).dy),
    );
  });

  detailTest('English UI leads with English', (tester) async {
    await pump(tester, _alert(), lang: 'en');
    expect(
      tester.getTopLeft(find.text('Heavy rain')).dy,
      lessThan(tester.getTopLeft(find.text('ฝนตกหนัก')).dy),
    );
  });

  detailTest('one language only: no second block, falls back to it', (
    tester,
  ) async {
    await pump(tester, _alert(headline: {'th': 'ฝนตกหนัก'}), lang: 'en');
    expect(find.text('ฝนตกหนัก'), findsOneWidget);
  });

  detailTest('no headline: the level word stands in', (tester) async {
    await pump(tester, _alert(headline: {}));
    expect(find.text('เตือนภัย'), findsNWidgets(2));
  });

  detailTest('stale data shows the out-of-date banner', (tester) async {
    await pump(
      tester,
      _alert(),
      generated: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);
  });

  detailTest('fresh data shows no stale banner', (tester) async {
    await pump(tester, _alert());
    expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);
  });

  detailTest('footer says it is an official notice, not an order', (
    tester,
  ) async {
    await pump(tester, _alert());
    expect(find.textContaining('ไม่ใช่คำสั่งจากแอปนี้'), findsOneWidget);
  });

  detailTest('1.5x text scale on 360x640 does not overflow', (tester) async {
    await pump(
      tester,
      _alert(
        codes: ['TH-10', 'TH-99'],
        headline: {
          'th': 'ประกาศเตือนภัยฝนตกหนักถึงหนักมากและน้ำท่วมฉับพลัน ' * 2,
          'en': 'Heavy to very heavy rain and flash flood warning ' * 2,
        },
      ),
      provinces: _fixture,
      textScale: 1.5,
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    // Scroll to the footer to prove the whole page lays out.
    await tester.scrollUntilVisible(
      find.textContaining('ไม่ใช่คำสั่งจากแอปนี้'),
      200,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a Home notice opens its detail', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final now = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.saveSnapshot(
      jsonEncode({
        'generatedAt': now.toIso8601String(),
        'alerts': [
          {
            'id': 'a',
            'sender': 'TMD',
            'status': 'Actual',
            'msgType': 'Alert',
            'level': 'warning',
            'headline': {'th': 'ฝนตกหนัก', 'en': 'Heavy rain'},
            'sent': now.subtract(const Duration(minutes: 10)).toIso8601String(),
            'expires': now.add(const Duration(hours: 3)).toIso8601String(),
            'areaCodes': ['TH-10'],
            'polygons': [],
          },
        ],
      }),
      now,
    );
    final sensors = SensorService();
    final service = AlertService(storage);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: HomeScreen(
            sensors: sensors,
            storage: storage,
            alerts: service,
            provinces: _fixture,
            location: LocationService(storage, lookup: (_, _) async => null),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final row = find.text('ฝนตกหนัก');
    await tester.ensureVisible(row);
    await tester.pump();
    final box = tester.getSize(
      find.ancestor(of: row, matching: find.byType(InkWell)).first,
    );
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDetailScreen), findsOneWidget);
    expect(find.text('กรุงเทพมหานคร · Bangkok'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    sensors.dispose();
    service.dispose();
  });
}
