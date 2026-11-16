import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/screens/sensors_screen.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// Contrast ratio between two colors (WCAG formula).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

// Sets the fake screen size and text scale for one test.
void _setScreen(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

// Builds the whole app on the fake screen; seeded=false leaves the shelter cache empty.
Future<StorageService> _pumpApp(
  WidgetTester tester, {
  bool seeded = true,
  bool english = false,
}) async {
  SharedPreferences.setMockInitialValues({if (english) 'language': 'en'});
  final storage = await StorageService.create();
  if (seeded) await storage.saveShelters(MockData.shelters);
  await tester.pumpWidget(
    DisasterApp(storage: storage, loadMap: failingLoadMap),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return storage;
}

// Removes the app so the sensor timer is cancelled before the test ends.
Future<void> _teardownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    useScreenshotWriter();
    mockPathProvider();
  });

  const tabs = ['หน้าแรก', 'เซนเซอร์', 'แผนที่', 'รายงาน', 'คู่มือ'];
  const sizes = {
    'phone-360x640': Size(360, 640),
    'phone-390x844': Size(390, 844),
    'tablet-820x1180': Size(820, 1180),
    'landscape-844x390': Size(844, 390),
  };

  group('tokens', () {
    test('text pairs reach 4.5:1 and UI pairs 3:1', () {
      const t = AppTokens.light;
      for (final tier in AlertTier.values) {
        final s = t.tier(tier);
        expect(
          _contrast(s.onColor, s.color),
          greaterThanOrEqualTo(4.5),
          reason: s.label,
        );
      }
      final textPairs = {
        'ink/ground': (t.ink, t.ground),
        'ink/surface': (t.ink, t.surface),
        'inkMuted/ground': (t.inkMuted, t.ground),
        'inkMuted/surface': (t.inkMuted, t.surface),
        'ink/infoBg': (t.ink, t.infoBg),
        'ink/offlineBg': (t.ink, t.offlineBg),
        'ink/errorBg': (t.ink, t.errorBg),
        'onAccent/accent': (t.onAccent, t.accent),
        'accent/surface': (t.accent, t.surface),
        'accent/ground': (t.accent, t.ground),
        'onDanger/danger': (t.onDanger, t.danger),
        'danger/surface': (t.danger, t.surface),
      };
      textPairs.forEach((name, p) {
        expect(_contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: name);
      });
      final uiPairs = {
        'outline/surface': (t.outline, t.surface),
        'accent/hairline': (t.accent, t.hairline),
        'danger/hairline': (t.danger, t.hairline),
        'ink/hairline': (t.ink, t.hairline),
      };
      uiPairs.forEach((name, p) {
        expect(_contrast(p.$1, p.$2), greaterThanOrEqualTo(3.0), reason: name);
      });
    });

    test('the four tiers have distinct icons and labels', () {
      const t = AppTokens.light;
      final icons = AlertTier.values.map((e) => t.tier(e).icon).toSet();
      final labels = AlertTier.values.map((e) => t.tier(e).label).toSet();
      expect(icons.length, 4);
      expect(labels.length, 4);
    });

    test('body text is at least 16 sp', () {
      final text = AppTheme.light().textTheme;
      expect(text.bodyMedium!.fontSize, greaterThanOrEqualTo(16));
      expect(text.bodyLarge!.fontSize, greaterThanOrEqualTo(16));
      expect(text.bodySmall!.fontSize, greaterThanOrEqualTo(16));
      expect(text.bodyMedium!.fontFamily, 'Sarabun');
    });
  });

  group('layouts do not overflow', () {
    for (final entry in sizes.entries) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('${entry.key} at ${scale}x text', (tester) async {
          _setScreen(tester, entry.value, textScale: scale);
          // Empty shelter cache is the worst case (empty state plus the map-file error banner).
          await _pumpApp(tester, seeded: false);
          for (final tab in tabs) {
            await tester.tap(find.text(tab).first);
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              tester.takeException(),
              isNull,
              reason: '$tab on ${entry.key} at ${scale}x',
            );
          }
          await _teardownApp(tester);
        });
      }
    }
  });

  group('accessibility guidelines', () {
    for (final tab in tabs) {
      testWidgets('$tab: tap targets and labels (Thai)', (tester) async {
        _setScreen(tester, const Size(390, 844));
        final handle = tester.ensureSemantics();
        await _pumpApp(tester);
        await tester.tap(find.text(tab).first);
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        await _teardownApp(tester);
      });
    }

    // Flutter's text-contrast check samples screenshot pixels, and thin Thai glyphs fool it
    // (it reports 1.4:1 for dark ink on white). The English UI uses the same colors, so the
    // pixel check runs there; the exact color pairs are verified in the 'tokens' group.
    const tabsEn = ['Home', 'Sensors', 'Map', 'Report', 'Guide'];
    for (final tab in tabsEn) {
      testWidgets('$tab: text contrast (English)', (tester) async {
        _setScreen(tester, const Size(390, 844));
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, english: true);
        await tester.tap(find.text(tab).first);
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        await _teardownApp(tester);
      });
    }
  });

  group('SOS press and hold', () {
    testWidgets('a quick tap does nothing, a 1.6 s hold opens the dialog', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      await _pumpApp(tester);
      final sos = find.text('SOS');
      expect(sos, findsOneWidget);

      await tester.tap(sos);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('หาตำแหน่งของคุณไม่ได้'), findsNothing);

      final gesture = await tester.startGesture(tester.getCenter(sos));
      await tester.pump(); // the ticker starts on the first frame
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      // Platform-channel replies arrive in real time, outside the fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // GPS is unavailable in tests, so the clear error dialog (not a crash) must appear.
      expect(find.text('หาตำแหน่งของคุณไม่ได้'), findsOneWidget);
      await tester.tap(find.text('ปิด'));
      await tester.pump(const Duration(milliseconds: 300));
      await _teardownApp(tester);
    });
  });

  group('screenshots (goldens)', () {
    for (final entry in sizes.entries) {
      testWidgets('home ${entry.key}', (tester) async {
        _setScreen(tester, entry.value);
        await _pumpApp(tester);
        await expectLater(
          find.byType(DisasterApp),
          matchesGoldenFile('goldens/home_${entry.key}.png'),
        );
        await _teardownApp(tester);
      });
    }

    testWidgets('home 360x640 at 1.5x text', (tester) async {
      _setScreen(tester, const Size(360, 640), textScale: 1.5);
      await _pumpApp(tester);
      await expectLater(
        find.byType(DisasterApp),
        matchesGoldenFile('goldens/home_360x640_scale1.5.png'),
      );
      await _teardownApp(tester);
    });

    for (final (tab, slug) in [
      ('เซนเซอร์', 'sensors'),
      ('แผนที่', 'map'),
      ('รายงาน', 'report'),
      ('คู่มือ', 'guide'),
    ]) {
      testWidgets('$slug 390x844', (tester) async {
        _setScreen(tester, const Size(390, 844));
        await _pumpApp(tester);
        await tester.tap(find.text(tab).first);
        // Let failed tile downloads (real time) report, then settle the tab animation.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1000));
        await expectLater(
          find.byType(DisasterApp),
          matchesGoldenFile('goldens/${slug}_390x844.png'),
        );
        await _teardownApp(tester);
      });
    }

    testWidgets('sensors over the limit', (tester) async {
      _setScreen(tester, const Size(390, 844));
      SharedPreferences.setMockInitialValues({});
      final sensors = SensorService()..simulateWater(200);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(body: SensorsScreen(sensors: sensors)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sensors_over_limit_390x844.png'),
      );
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
    });

    testWidgets('Thai sample text keeps its tone marks at 1.0x and 1.5x', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 640), textScale: 1.5);
      const sample =
          'ผู้ปฏิบัติงานกู้ภัย น้ำท่วมสูง ๑๕๐ ซม. ปลอดภัย เฝ้าระวัง อพยพ';
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final text = Theme.of(context).textTheme;
                return ListView(
                  padding: const EdgeInsets.all(AppSpace.md),
                  children: [
                    Text(sample, style: text.displaySmall),
                    Text(sample, style: text.titleLarge),
                    Text(sample, style: text.bodyLarge),
                    Text(sample, style: text.bodyMedium),
                    Text(sample, style: text.labelMedium),
                  ],
                );
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/thai_sample_scale1.5.png'),
      );
    });

    testWidgets('all four alert levels', (tester) async {
      _setScreen(tester, const Size(390, 520));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                for (final tier in AlertTier.values)
                  Builder(
                    builder: (context) {
                      final s = context.tokens.tier(tier);
                      return Expanded(
                        child: Container(
                          color: s.color,
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Row(
                            children: [
                              Icon(s.icon, size: 56, color: s.onColor),
                              const SizedBox(width: AppSpace.md),
                              Text(
                                s.label,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(color: s.onColor),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/alert_levels.png'),
      );
    });
  });
}
