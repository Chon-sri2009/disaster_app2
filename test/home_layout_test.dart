import 'dart:convert';

import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/screens/alert_detail_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// Home layout: the SOS bar must stay reachable on short screens and at large text, and the
// level slab must never claim Safe without data.
void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  late SensorService sensors;
  AlertService? alertService;

  Future<StorageService> pump(
    WidgetTester tester, {
    required Size size,
    double scale = 1.0,
    SensorService? sensor,
    LatLng? at,
    bool shelters = false,
    List<Map<String, Object?>>? alertJson,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    if (shelters) await storage.saveShelters(MockData.shelters);
    if (at != null) await storage.saveLastPosition(at);
    sensors = sensor ?? SensorService();
    AlertService? alerts;
    if (alertJson != null) {
      final now = DateTime.now().toUtc();
      await storage.saveSnapshot(
        jsonEncode({'generatedAt': now.toIso8601String(), 'alerts': alertJson}),
        now,
      );
      alerts = AlertService(storage);
      alertService = alerts;
    }
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('th'),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: HomeScreen(
            sensors: sensors,
            storage: storage,
            alerts: alerts,
            location: LocationService(storage, lookup: (_, _) async => null),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return storage;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    sensors.dispose();
    alertService?.dispose();
    alertService = null;
  }

  // A live sensor with no answer: level is null, so Home must say "no live data".
  SensorService unreachable() => SensorService(
    snapshotUrl: 'https://example.test/snapshot',
    fetcher: (_) async => throw StateError('offline'),
  );

  SensorService danger() => SensorService()..simulateWater(200);

  SensorService liveWatch() => SensorService(
    snapshotUrl: 'https://example.test/snapshot',
    fetcher: (_) async =>
        '{"generatedAt":"${DateTime.now().toUtc().toIso8601String()}",'
        '"stations":[{"id":"s1","name":"S","band":"watch","status":"ok",'
        '"waterCm":50,"readingTime":"2026-11-21T00:00:00Z"}]}',
  );

  group('SOS stays reachable', () {
    final cases = <(String, Size, double, bool)>[
      ('360x540 1x', const Size(360, 540), 1.0, false),
      ('360x540 1.5x', const Size(360, 540), 1.5, false),
      ('844x290 landscape', const Size(844, 290), 1.0, false),
      ('390x744 1.5x danger', const Size(390, 744), 1.5, true),
      ('390x844 1x danger (tall, pinned)', const Size(390, 844), 1.0, true),
    ];
    for (final (name, size, scale, loud) in cases) {
      testWidgets(name, (tester) async {
        await pump(
          tester,
          size: size,
          scale: scale,
          sensor: loud ? danger() : null,
          at: LatLng(13.75, 100.5),
          shelters: true,
        );
        await tester.pump(const Duration(milliseconds: 300));
        final sos = find.text('SOS');
        expect(sos, findsOneWidget);
        expect(sos.hitTestable(), findsOneWidget, reason: 'at rest');
        // Drag to the very end of the page.
        for (var i = 0; i < 4; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -2000),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(sos.hitTestable(), findsOneWidget, reason: 'after scrolling');
        expect(tester.takeException(), isNull);
        await finish(tester);
      });
    }
  });

  // The level, its step and its advice are the point of Home: they must be on screen above the
  // nav bar without scrolling, even on short screens at large text.
  group('level and advice visible without scrolling', () {
    final cases = <(String, Size, double)>[
      ('360x640 1.5x', const Size(360, 640), 1.5),
      ('360x640 1x', const Size(360, 640), 1.0),
      ('844x390 landscape', const Size(844, 390), 1.0),
      ('390x844 1x', const Size(390, 844), 1.0),
    ];
    for (final (name, size, scale) in cases) {
      for (final kind in ['danger', 'calm', 'nodata']) {
        testWidgets('$name $kind', (tester) async {
          await pump(
            tester,
            size: size,
            scale: scale,
            sensor: switch (kind) {
              'danger' => danger(),
              'nodata' => unreachable(),
              _ => null,
            },
          );
          await tester.pump(const Duration(milliseconds: 300));
          final slab = tester.widget<LevelSlab>(find.byType(LevelSlab));
          final limit = size.height - AppSize.navBar;
          Finder inSlab(String text) => find
              .descendant(of: find.byType(LevelSlab), matching: find.text(text))
              .first;
          void inView(String what, Finder f) {
            expect(f, findsOneWidget, reason: what);
            final r = tester.getRect(f);
            expect(r.top, greaterThanOrEqualTo(0), reason: '$what top');
            expect(r.bottom, lessThanOrEqualTo(limit), reason: '$what bottom');
          }

          inView('level word', inSlab(slab.label));
          inView('advice', inSlab(slab.advice));
          if (slab.step != null) inView('step', inSlab(slab.step!));
          // SOS is reachable at rest too.
          expect(find.text('SOS').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await finish(tester);
        });
      }
    }
  });

  testWidgets('gauge is a staff: four equal blocks, lowest tier at the bottom, '
      'as tall as the slab text', (tester) async {
    await pump(tester, size: const Size(390, 844), sensor: danger());
    final tops = <double>[];
    for (final step in ['danger', 'warning', 'watch', 'safe']) {
      final f = find.byKey(
        ValueKey('gauge-$step${step == 'danger' ? '-filled' : ''}'),
      );
      expect(f, findsOneWidget, reason: step);
      final r = tester.getRect(f);
      expect(r.width, greaterThanOrEqualTo(AppSize.gaugeWidth));
      tops.add(r.top);
    }
    expect(tops, orderedEquals([...tops]..sort()), reason: 'danger on top');
    final heights = [
      for (final step in ['warning', 'watch', 'safe'])
        tester.getSize(find.byKey(ValueKey('gauge-$step'))).height,
    ];
    expect(heights.toSet().length, 1, reason: 'equal blocks');
    final gauge = tester.getRect(find.byType(LevelGauge));
    final slab = tester.getRect(find.byType(LevelSlab));
    expect(gauge.height, greaterThan(AppSize.gaugeWidth * 3));
    expect(gauge.height, lessThanOrEqualTo(slab.height));
    await finish(tester);
  });

  group('level slab', () {
    testWidgets('no data: says so, never Safe, no filled gauge block', (
      tester,
    ) async {
      await pump(tester, size: const Size(390, 844), sensor: unreachable());
      expect(find.text('ไม่มีข้อมูลสด'), findsWidgets);
      expect(find.text('ปลอดภัย'), findsNothing);
      expect(
        find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey<String> &&
              k.value.startsWith('gauge-') &&
              k.value.endsWith('-filled');
        }),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('watch: icon block and the quiet slab', (tester) async {
      await pump(tester, size: const Size(390, 844), sensor: liveWatch());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('watch-icon-block')), findsOneWidget);
      expect(find.byType(LevelSlab), findsOneWidget);
      await finish(tester);
    });

    testWidgets('danger: slab and SOS bar are separate boxes', (tester) async {
      await pump(tester, size: const Size(390, 844), sensor: danger());
      final slab = tester.getRect(find.byType(LevelSlab));
      final bar = tester.getRect(find.byType(SosBar));
      expect(bar.top - slab.bottom, greaterThanOrEqualTo(AppSpace.sm));
      await finish(tester);
    });
  });

  testWidgets('settings button is at least 48 dp', (tester) async {
    await pump(tester, size: const Size(390, 844));
    final size = tester.getSize(find.byTooltip('ตั้งค่า'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await finish(tester);
  });

  testWidgets('a notice row is one labelled button and opens the notice', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final now = DateTime.now().toUtc();
    await pump(
      tester,
      size: const Size(390, 844),
      alertJson: [
        {
          'id': 'a',
          'sender': 'TMD',
          'status': 'Actual',
          'msgType': 'Alert',
          'level': 'warning',
          'headline': {'th': 'หัวข้อ a', 'en': 'Headline a'},
          'sent': now.subtract(const Duration(minutes: 10)).toIso8601String(),
          'expires': now.add(const Duration(hours: 3)).toIso8601String(),
          'areaCodes': <String>[],
          'polygons': <List<List<double>>>[],
        },
      ],
    );
    // The row is one labelled button and a screen reader can activate it.
    expect(find.semantics.byLabel(RegExp('หัวข้อ a')), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel(RegExp('หัวข้อ a')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDetailScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('หัวข้อ a'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDetailScreen), findsOneWidget);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    sensors.dispose();
    alertService?.dispose();
  });
}
