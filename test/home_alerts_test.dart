import 'dart:convert';

import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/alert_rules.dart';
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

// Two small square "provinces": TH-10 around the test phone, TH-50 far north.
final _fixture = ProvinceBoundaries.parse(
  jsonEncode({
    'provinces': [
      {
        'code': 'TH-10',
        'nameTh': 'ก',
        'nameEn': 'A',
        'rings': [
          [
            [100.0, 13.0],
            [101.0, 13.0],
            [101.0, 14.0],
            [100.0, 14.0],
          ],
        ],
      },
      {
        'code': 'TH-50',
        'nameTh': 'ข',
        'nameEn': 'B',
        'rings': [
          [
            [98.5, 18.5],
            [99.5, 18.5],
            [99.5, 19.5],
            [98.5, 19.5],
          ],
        ],
      },
    ],
  }),
);

final _home = LatLng(13.5, 100.5);

OfficialAlert _alert({
  String id = 'a',
  List<String> areaCodes = const [],
  List<List<LatLng>> polygons = const [],
  AlertLevel level = AlertLevel.warning,
}) => OfficialAlert(
  id: id,
  sender: 'TMD',
  status: 'Actual',
  msgType: 'Alert',
  level: level,
  headline: {'th': 'หัวข้อ $id', 'en': 'Headline $id'},
  sent: DateTime.utc(2026, 11, 12),
  areaCodes: areaCodes,
  polygons: polygons,
);

// A square around the far-north province, nowhere near the test phone.
final _farPolygon = [
  LatLng(18.5, 98.5),
  LatLng(18.5, 99.5),
  LatLng(19.5, 99.5),
  LatLng(19.5, 98.5),
];

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('AlertRules.areaOf', () {
    test('polygon alert: inside is in your area, outside is other areas', () {
      final inside = _alert(
        polygons: [
          [LatLng(13, 100), LatLng(13, 101), LatLng(14, 101), LatLng(14, 100)],
        ],
      );
      expect(AlertRules.areaOf(inside, _home, 'TH-10'), AlertArea.inYourArea);
      expect(
        AlertRules.areaOf(_alert(polygons: [_farPolygon]), _home, 'TH-10'),
        AlertArea.otherAreas,
      );
      // A polygon decides alone, so an unknown province changes nothing.
      expect(
        AlertRules.areaOf(_alert(polygons: [_farPolygon]), _home, null),
        AlertArea.otherAreas,
      );
    });

    test('code-only alert: needs a known province to say anything', () {
      final a = _alert(areaCodes: ['TH-10']);
      expect(AlertRules.areaOf(a, _home, 'TH-10'), AlertArea.inYourArea);
      expect(AlertRules.areaOf(a, _home, 'TH-50'), AlertArea.otherAreas);
      expect(AlertRules.areaOf(a, _home, null), AlertArea.unknown);
    });

    test('area-less alert is unknown even when the province is known', () {
      final a = _alert();
      expect(AlertRules.areaOf(a, _home, 'TH-10'), AlertArea.unknown);
      expect(AlertRules.areaOf(a, _home, null), AlertArea.unknown);
      // Ranks after in-your-area and before other-areas (Home sorts by enum order).
      expect(
        AlertArea.inYourArea.index,
        lessThan(AlertRules.areaOf(a, _home, 'TH-10').index),
      );
      expect(
        AlertRules.areaOf(a, _home, 'TH-10').index,
        lessThan(AlertArea.otherAreas.index),
      );
    });

    test('no location is always unknown', () {
      expect(
        AlertRules.areaOf(_alert(areaCodes: ['TH-10']), null, 'TH-10'),
        AlertArea.unknown,
      );
      expect(
        AlertRules.areaOf(_alert(polygons: [_farPolygon]), null, null),
        AlertArea.unknown,
      );
    });

    test('the tag never disagrees with matches()', () {
      final alerts = [
        _alert(areaCodes: ['TH-10']),
        _alert(areaCodes: ['TH-50']),
        _alert(polygons: [_farPolygon]),
        _alert(),
      ];
      for (final a in alerts) {
        for (final code in ['TH-10', 'TH-50', null]) {
          final tag = AlertRules.areaOf(a, _home, code);
          expect(
            tag == AlertArea.inYourArea,
            AlertRules.matches(a, _home, code),
          );
        }
      }
    });
  });

  group('Home notices', () {
    Future<void> Function() cleanup = () async {};
    void homeTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        await body(tester);
        await cleanup();
      });
    }

    // Pumps Home with a cached snapshot made from [alerts] (generated just now).
    Future<void> pump(
      WidgetTester tester,
      List<Map<String, Object?>> alerts, {
      LatLng? at,
      ProvinceBoundaries? provinces,
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      await storage.saveSnapshot(
        jsonEncode({'generatedAt': now.toIso8601String(), 'alerts': alerts}),
        now,
      );
      if (at != null) await storage.saveLastPosition(at);
      final sensors = SensorService();
      final service = AlertService(storage);
      cleanup = () async {
        // Remove the tree first so the sensors' timer is cancelled before the test ends.
        await tester.pumpWidget(const SizedBox());
        sensors.dispose();
        service.dispose();
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('th'),
          supportedLocales: const [Locale('th'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: HomeScreen(
              sensors: sensors,
              storage: storage,
              alerts: service,
              provinces: provinces,
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    Map<String, Object?> json(
      String id, {
      List<String> codes = const [],
      List<List<List<double>>> polygons = const [],
      String level = 'warning',
    }) {
      final now = DateTime.now().toUtc();
      return {
        'id': id,
        'sender': 'TMD',
        'status': 'Actual',
        'msgType': 'Alert',
        'level': level,
        'headline': {'th': 'หัวข้อ $id', 'en': 'Headline $id'},
        'sent': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'expires': now.add(const Duration(hours: 3)).toIso8601String(),
        'areaCodes': codes,
        'polygons': polygons,
      };
    }

    const officialSource = 'ประกาศเตือนภัยทางการ ในพื้นที่ล่าสุดของคุณ';
    const inArea = 'ในพื้นที่ของคุณ';
    const other = 'พื้นที่อื่น';
    const unknown = 'ไม่ทราบพื้นที่';

    homeTest('geocode-only warning for my province: level and tag agree', (
      tester,
    ) async {
      await pump(
        tester,
        [
          json('a', codes: ['TH-10']),
        ],
        at: _home,
        provinces: _fixture,
      );
      expect(find.text(officialSource), findsOneWidget);
      expect(find.text('เตือนภัย'), findsWidgets);
      expect(find.text(inArea), findsOneWidget);
      expect(find.text(other), findsNothing);
    });

    homeTest('same alert for another province: not my level, other areas', (
      tester,
    ) async {
      await pump(
        tester,
        [
          json('a', codes: ['TH-50']),
        ],
        at: _home,
        provinces: _fixture,
      );
      expect(find.text(officialSource), findsNothing);
      expect(find.text(other), findsOneWidget);
      expect(find.text(inArea), findsNothing);
      // Nothing is hidden: the notice itself is still listed.
      expect(find.text('หัวข้อ a'), findsOneWidget);
    });

    homeTest('no stored location: area unknown and level unchanged', (
      tester,
    ) async {
      await pump(tester, [
        json('a', codes: ['TH-10']),
      ], provinces: _fixture);
      expect(find.text(officialSource), findsNothing);
      expect(find.text(unknown), findsOneWidget);
      expect(find.text(inArea), findsNothing);
      expect(find.text(other), findsNothing);
    });

    homeTest('polygon far away is other areas', (tester) async {
      await pump(
        tester,
        [
          json(
            'a',
            polygons: [
              [
                [98.5, 18.5],
                [99.5, 18.5],
                [99.5, 19.5],
                [98.5, 19.5],
              ],
            ],
          ),
        ],
        at: _home,
        provinces: _fixture,
      );
      expect(find.text(other), findsOneWidget);
      expect(find.text(officialSource), findsNothing);
    });

    homeTest('polygonless alert while the locator is not loaded: unknown', (
      tester,
    ) async {
      await pump(tester, [
        json('a', codes: ['TH-10']),
      ], at: _home);
      expect(find.text(unknown), findsOneWidget);
      expect(find.text(other), findsNothing);
      expect(find.text(officialSource), findsNothing);
    });

    homeTest('a location outside every province is unknown, not other', (
      tester,
    ) async {
      await pump(
        tester,
        [
          json('a', codes: ['TH-10']),
        ],
        at: LatLng(5.0, 105.0),
        provinces: _fixture,
      );
      expect(find.text(unknown), findsOneWidget);
      expect(find.text(other), findsNothing);
    });

    homeTest('sorts in your area, then unknown, then other areas', (
      tester,
    ) async {
      // Province not known (at sea), so: polygon far (other), code-only (unknown),
      // polygon around the phone (in your area). Listed in the worst order.
      await pump(
        tester,
        [
          json(
            'far',
            polygons: [
              [
                [98.5, 18.5],
                [99.5, 18.5],
                [99.5, 19.5],
                [98.5, 19.5],
              ],
            ],
          ),
          json('code', codes: ['TH-10']),
          json(
            'near',
            polygons: [
              [
                [105.0, 4.0],
                [106.0, 4.0],
                [106.0, 6.0],
                [105.0, 6.0],
              ],
            ],
          ),
        ],
        at: LatLng(5.0, 105.5),
        provinces: _fixture,
      );
      double y(String id) => tester.getTopLeft(find.text('หัวข้อ $id')).dy;
      expect(y('near'), lessThan(y('code')));
      expect(y('code'), lessThan(y('far')));
      expect(find.text(inArea), findsOneWidget);
      expect(find.text(unknown), findsOneWidget);
      expect(find.text(other), findsOneWidget);
    });

    homeTest('semantics label of a row carries the area tag', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        [
          json('a', codes: ['TH-10']),
        ],
        at: _home,
        provinces: _fixture,
      );
      expect(
        find.bySemanticsLabel(RegExp('หัวข้อ a.*$inArea')),
        findsOneWidget,
      );
      handle.dispose();
    });

    homeTest('1.5x text scale does not overflow', (tester) async {
      await pump(
        tester,
        [
          json('a', codes: ['TH-10']),
          json('b', codes: ['TH-50']),
        ],
        at: _home,
        provinces: _fixture,
        textScale: 1.5,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(inArea), findsOneWidget);
      expect(find.text(other), findsOneWidget);
    });
  });
}
