import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/models/shelter.dart';
import 'package:disaster_app2/screens/map_screen.dart';
import 'package:disaster_app2/services/offline_map.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';
import 'package:disaster_app2/widgets/soft_ui.dart';
import 'package:disaster_app2/widgets/warning_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R8: the Map tab in the Posted notice style. The map tiles stay blank here (neverLoadMap), so
// these tests check the title, the offline banner, the sheet, the two text tabs and the lists:
// no cards, no shadows, no BrandHeader, 48 dp targets, no overflow at 1.5x Thai.

const _sizes = {
  'phone-360x640': Size(360, 640),
  'phone-390x844': Size(390, 844),
  'wide-820x600': Size(820, 600),
};

const _shelterTab = ValueKey('map-tab-shelters');
const _sensorTab = ValueKey('map-tab-sensors');

Future<({StorageService storage, SensorService sensors})> _pump(
  WidgetTester tester, {
  required Size size,
  double scale = 1.0,
  bool dark = false,
  bool shelters = true,
  bool position = true,
  bool realShelters = false,
  String lang = 'th',
  OfflineMapLoader? loadMap,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  if (shelters) {
    await storage.saveShelters(
      realShelters
          ? const [
              Shelter(
                id: 'real-1',
                name: 'Temple Hall',
                nameTh: 'ศาลาวัดพระศรีมหาธาตุ',
                lat: 13.87,
                lng: 100.6,
                capacity: 120,
              ),
              Shelter(
                id: 'real-2',
                name: 'School Gym',
                lat: 13.88,
                lng: 100.61,
              ),
            ]
          : MockData.shelters,
    );
  }
  if (position) await storage.saveLastPosition(MockData.areaCenter);
  final sensors = SensorService()..simulateWater(200);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: Locale(lang),
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: MapScreen(
            storage: storage,
            sensors: sensors,
            loadMap: loadMap ?? ({required bool thai}) => neverLoadMap(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  _sensors.add(sensors);
  return (storage: storage, sensors: sensors);
}

// The Posted notice rules: no card parts, no shadow, no tinted disc, 48 dp tap targets.
void _expectNoticeStyle(WidgetTester tester, AppTokens t, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
  for (final type in [
    Card,
    SegmentedButton<bool>,
    SoftCard,
    SoftTile,
    AccentRow,
    StatusPill,
    BrandHeader,
  ]) {
    expect(find.byType(type), findsNothing, reason: '$type $reason');
  }
  expect(find.byType(ScreenTitle), findsOneWidget, reason: reason);
  final shadowed = find.byWidgetPredicate((w) {
    if (w is! DecoratedBox) return false;
    final d = w.decoration;
    return d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false);
  });
  expect(shadowed, findsNothing, reason: 'no shadow $reason');
  final tinted = find.byWidgetPredicate((w) {
    final d = w is DecoratedBox ? w.decoration : null;
    return d is BoxDecoration && d.color == t.brandSoft;
  });
  expect(tinted, findsNothing, reason: 'no brandSoft disc $reason');
  final taps = find.byWidgetPredicate((w) => w is InkWell && w.onTap != null);
  for (final e in taps.evaluate()) {
    final box = e.renderObject! as RenderBox;
    expect(
      box.size.height,
      greaterThanOrEqualTo(AppSize.tapTarget - 0.01),
      reason: 'tap height $reason',
    );
  }
}

final _sensors = <SensorService>[];

// testWidgets that removes the screen and stops the sensor timer before the test ends.
void _testMap(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final s in _sensors) {
        s.dispose();
      }
      _sensors.clear();
    }
  });
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    useScreenshotWriter();
  });

  group('posted notice style', () {
    for (final entry in _sizes.entries) {
      for (final scale in [1.0, 1.5]) {
        for (final dark in [false, true]) {
          for (final shelters in [true, false]) {
            final name =
                '${entry.key} x$scale ${dark ? 'dark' : 'light'} '
                '${shelters ? 'shelters' : 'no shelters'}';
            _testMap(name, (tester) async {
              await _pump(
                tester,
                size: entry.value,
                scale: scale,
                dark: dark,
                shelters: shelters,
              );
              final t = dark ? AppTokens.dark : AppTokens.light;
              _expectNoticeStyle(tester, t, name);
              // Both tabs exist, 48 dp tall, and the shelters tab starts selected.
              for (final key in [_shelterTab, _sensorTab]) {
                final box = tester.getSize(find.byKey(key));
                expect(box.height, greaterThanOrEqualTo(AppSize.tapTarget));
                expect(box.width, greaterThanOrEqualTo(AppSize.tapTarget));
              }
              if (!shelters) {
                expect(find.byType(WarningBanner), findsOneWidget);
              }
            });
          }
        }
      }
    }
  });

  group('tabs', () {
    _testMap('selected tab has the underline and the selected semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: _sizes['phone-390x844']!);
      final t = AppTokens.light;

      Color rule(ValueKey<String> key) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byKey(const ValueKey('map-tab-rule')),
          ),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      expect(rule(_shelterTab), t.brand);
      expect(rule(_sensorTab), Colors.transparent);
      expect(
        tester.getSemantics(find.byKey(_shelterTab)),
        isSemantics(
          label: 'ศูนย์พักพิง',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_sensorTab)),
        isSemantics(
          label: 'เซนเซอร์',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      // The selected tab is also bolder, so the state is not colour alone.
      TextStyle? style(ValueKey<String> key) => tester
          .widget<Text>(
            find.descendant(of: find.byKey(key), matching: find.byType(Text)),
          )
          .style;
      expect(
        style(_shelterTab)!.fontWeight!.value,
        greaterThan(style(_sensorTab)!.fontWeight!.value),
      );

      await tester.tap(find.byKey(_sensorTab));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rule(_sensorTab), t.brand);
      expect(rule(_shelterTab), Colors.transparent);
      // The sensors list shows the demo gauges, not the shelter list.
      expect(find.text('ระดับน้ำ'), findsOneWidget);
      expect(
        find.text('ศูนย์พักพิง (${MockData.shelters.length})'),
        findsNothing,
      );
      _expectNoticeStyle(tester, t, 'sensors tab');
      handle.dispose();
    });

    for (final entry in _sizes.entries) {
      _testMap('sensors tab ${entry.key} 1.5x dark', (tester) async {
        await _pump(tester, size: entry.value, scale: 1.5, dark: true);
        await tester.tap(find.byKey(_sensorTab));
        await tester.pump(const Duration(milliseconds: 300));
        _expectNoticeStyle(tester, AppTokens.dark, 'sensors ${entry.key}');
      });
    }
  });

  group('sheet', () {
    _testMap('phone sheet has a square top edge and no shadow', (tester) async {
      await _pump(tester, size: _sizes['phone-390x844']!);
      final sheet = tester.widget<Container>(
        find.byKey(const ValueKey('map-sheet')),
      );
      final deco = sheet.decoration! as BoxDecoration;
      expect(deco.borderRadius, isNull);
      expect(deco.boxShadow, isNull);
    });

    _testMap('drag handle keeps a 48 dp grab area', (tester) async {
      await _pump(tester, size: _sizes['phone-390x844']!);
      final grab = tester.getSize(find.byKey(const ValueKey('map-sheet-grab')));
      expect(grab.height, greaterThanOrEqualTo(AppSize.tapTarget));
    });

    _testMap('wide screen keeps the 340 dp side column, no handle', (
      tester,
    ) async {
      await _pump(tester, size: _sizes['wide-820x600']!);
      expect(
        tester.getSize(find.byKey(const ValueKey('map-side-column'))).width,
        AppSize.sidePanelWidth,
      );
      expect(find.byKey(const ValueKey('map-sheet-grab')), findsNothing);
    });
  });

  group('lists', () {
    _testMap('shelter rows are ruled rows with 48 dp and the sample notice', (
      tester,
    ) async {
      await _pump(tester, size: _sizes['phone-390x844']!);
      expect(find.text('ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง'),
          matching: find.byType(Tag),
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump();
      expect(find.byType(RuledRow), findsWidgets);
      for (final e in find.byType(RuledRow).evaluate()) {
        expect(
          (e.renderObject! as RenderBox).size.height,
          greaterThanOrEqualTo(AppSize.tapTarget),
        );
      }
    });

    _testMap('real shelters: no sample notice, nearest tag on the first row', (
      tester,
    ) async {
      await _pump(tester, size: _sizes['phone-390x844']!, realShelters: true);
      expect(find.text('ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง'), findsNothing);
      expect(find.text('ใกล้สุด'), findsOneWidget);
      expect(find.byType(RuledRow), findsNWidgets(2));
    });

    _testMap('empty list says so in a banner, not as safe', (tester) async {
      await _pump(tester, size: _sizes['phone-360x640']!, shelters: false);
      expect(
        find.textContaining('ยังไม่มีรายชื่อศูนย์พักพิงในเครื่อง'),
        findsOneWidget,
      );
    });

    _testMap('English at 1.5x on a small phone has no overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        size: _sizes['phone-360x640']!,
        scale: 1.5,
        lang: 'en',
        realShelters: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Shelters'), findsWidgets);
    });
  });

  group('offline notice', () {
    for (final entry in _sizes.entries) {
      for (final scale in [1.0, 1.5]) {
        _testMap('${entry.key} x$scale shows the flat offline banner', (
          tester,
        ) async {
          await _pump(
            tester,
            size: entry.value,
            scale: scale,
            loadMap: failingLoadMap,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 300));
          final banner = find.byWidgetPredicate(
            (w) => w is WarningBanner && w.kind == BannerKind.offline,
          );
          expect(banner, findsOneWidget);
          expect(find.text('ลองอีกครั้ง'), findsOneWidget);
          _expectNoticeStyle(tester, AppTokens.light, 'offline');
          // The retry button keeps 48 dp.
          expect(
            tester
                .getSize(find.widgetWithText(TextButton, 'ลองอีกครั้ง'))
                .height,
            greaterThanOrEqualTo(AppSize.tapTarget),
          );
        });
      }
    }
  });

  group('markers', () {
    _testMap('map legend marks are flat and keep distinct shapes', (
      tester,
    ) async {
      await _pump(tester, size: _sizes['phone-390x844']!);
      // Legend: a square (shelter) and a circle (station), both without shadow.
      final marks = find.byKey(const ValueKey('legend-shelter'));
      final station = find.byKey(const ValueKey('legend-station'));
      expect(marks, findsOneWidget);
      expect(station, findsOneWidget);
      final shelterDeco =
          tester.widget<Container>(marks).decoration! as BoxDecoration;
      final stationDeco =
          tester.widget<Container>(station).decoration! as BoxDecoration;
      expect(shelterDeco.shape, BoxShape.rectangle);
      expect(shelterDeco.borderRadius, isNull);
      expect(stationDeco.shape, BoxShape.circle);
      expect(shelterDeco.boxShadow, isNull);
      expect(stationDeco.boxShadow, isNull);
    });
  });
}
