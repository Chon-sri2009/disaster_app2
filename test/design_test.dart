import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/sensor_readings.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  const tabs = ['หน้าแรก', 'แผนที่', 'โทร', 'รายงาน', 'คู่มือ'];
  const sizes = {
    'phone-360x640': Size(360, 640),
    'phone-390x844': Size(390, 844),
    'tablet-820x1180': Size(820, 1180),
    'landscape-844x390': Size(844, 390),
  };

  group('tokens', () {
    for (final (name, t) in [
      ('day', AppTokens.light),
      ('night', AppTokens.dark),
    ]) {
      test('$name board: text pairs reach 4.5:1 and UI pairs 3:1', () {
        for (final tier in AlertTier.values) {
          final s = t.tier(tier);
          expect(
            _contrast(s.onColor, s.color),
            greaterThanOrEqualTo(4.5),
            reason: '${s.label} field',
          );
          expect(
            _contrast(s.onGround, t.ground),
            greaterThanOrEqualTo(4.5),
            reason: '${s.label} on ground',
          );
          expect(
            _contrast(s.onGround, t.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${s.label} on surface',
          );
        }
        final textPairs = {
          'ink/ground': (t.ink, t.ground),
          'ink/surface': (t.ink, t.surface),
          'ink/pressed': (t.ink, t.pressed),
          'inkMuted/ground': (t.inkMuted, t.ground),
          'inkMuted/surface': (t.inkMuted, t.surface),
          'ink/offlineBg': (t.ink, t.offlineBg),
          'inkMuted/offlineBg': (t.inkMuted, t.offlineBg),
          'ink/errorBg': (t.ink, t.errorBg),
          'inkMuted/errorBg': (t.inkMuted, t.errorBg),
          'ground/ink (snackbar, tooltip)': (t.ground, t.ink),
          'onDanger/danger': (t.onDanger, t.danger),
          'onBrand/brand': (t.onBrand, t.brand),
          'brand/surface': (t.brand, t.surface),
          'brand/brandSoft': (t.brand, t.brandSoft),
          'ink/brandSoft': (t.ink, t.brandSoft),
          'inkMuted/brandSoft': (t.inkMuted, t.brandSoft),
          'onHeader/header': (t.onHeader, t.header),
          'onHeaderMuted/header': (t.onHeaderMuted, t.header),
          'dangerInk/ground': (t.dangerInk, t.ground),
          'dangerInk/surface': (t.dangerInk, t.surface),
          'dangerInk/errorBg': (t.dangerInk, t.errorBg),
        };
        textPairs.forEach((name, p) {
          expect(
            _contrast(p.$1, p.$2),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        });
        // Brand-filled marks (selected outline, shelter markers, the raised Call circle) and the
        // gauge's limit post must stand out from the card and the canvas.
        final uiPairs = {
          'brand/ground': (t.brand, t.ground),
          'brand/surface': (t.brand, t.surface),
          'limit post/surface': (t.ink, t.surface),
        };
        uiPairs.forEach((name, p) {
          expect(
            _contrast(p.$1, p.$2),
            greaterThanOrEqualTo(3.0),
            reason: name,
          );
        });
      });
    }

    test('the four tiers have distinct icons and labels', () {
      final t = AppTokens.light;
      final icons = AlertTier.values.map((e) => t.tier(e).icon).toSet();
      final labels = AlertTier.values.map((e) => t.tier(e).label).toSet();
      expect(icons.length, 4);
      expect(labels.length, 4);
    });

    test('Posted notice type scale: every slot, sizes, weights, figures', () {
      const roles = {
        'displayLarge': (48.0, FontWeight.w700),
        'displayMedium': (40.0, FontWeight.w700),
        'displaySmall': (36.0, FontWeight.w700),
        'headlineMedium': (28.0, FontWeight.w700),
        'headlineSmall': (24.0, FontWeight.w600),
        'titleLarge': (22.0, FontWeight.w600),
        'titleMedium': (20.0, FontWeight.w600),
        'titleSmall': (17.0, FontWeight.w600),
        'bodyLarge': (17.0, FontWeight.w400),
        'bodyMedium': (17.0, FontWeight.w400),
        'bodySmall': (16.0, FontWeight.w400),
        'labelLarge': (17.0, FontWeight.w600),
        'labelMedium': (16.0, FontWeight.w600),
        'labelSmall': (16.0, FontWeight.w400),
      };
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final tt = theme.textTheme;
        final slots = {
          'displayLarge': tt.displayLarge,
          'displayMedium': tt.displayMedium,
          'displaySmall': tt.displaySmall,
          'headlineLarge': tt.headlineLarge,
          'headlineMedium': tt.headlineMedium,
          'headlineSmall': tt.headlineSmall,
          'titleLarge': tt.titleLarge,
          'titleMedium': tt.titleMedium,
          'titleSmall': tt.titleSmall,
          'bodyLarge': tt.bodyLarge,
          'bodyMedium': tt.bodyMedium,
          'bodySmall': tt.bodySmall,
          'labelLarge': tt.labelLarge,
          'labelMedium': tt.labelMedium,
          'labelSmall': tt.labelSmall,
        };
        slots.forEach((name, style) {
          if (style == null) return; // headlineLarge is not in the scale
          expect(style.fontSize, greaterThanOrEqualTo(16), reason: name);
          expect(style.fontFamily, 'Sarabun', reason: name);
          expect(
            style.leadingDistribution,
            TextLeadingDistribution.even,
            reason: name,
          );
          final heavy =
              name.startsWith('display') || name == 'headlineMedium';
          if (!heavy) {
            expect(
              style.fontWeight,
              isNot(FontWeight.w700),
              reason: '$name: w700 is for display and headlineMedium only',
            );
          }
          if (name.startsWith('display')) {
            expect(
              style.fontFeatures,
              contains(const FontFeature.tabularFigures()),
              reason: '$name tabular figures',
            );
          }
        });
        roles.forEach((name, spec) {
          final style = slots[name]!;
          expect(style.fontSize, spec.$1, reason: '$name size');
          expect(style.fontWeight, spec.$2, reason: '$name weight');
        });
      }
    });

    for (final (name, t) in [
      ('day', AppTokens.light),
      ('night', AppTokens.dark),
    ]) {
      test('$name Posted notice marks, rules and hairline', () {
        expect(
          _contrast(t.mark, t.ground),
          greaterThanOrEqualTo(3.0),
          reason: 'mark/ground',
        );
        expect(
          _contrast(t.mark, t.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'mark/surface',
        );
        expect(
          _contrast(t.inkMuted, t.hairline),
          greaterThanOrEqualTo(4.5),
          reason: 'inkMuted/hairline',
        );
        for (final tier in AlertTier.values) {
          final s = t.tier(tier);
          // Day WATCH yellow is about 1.5:1 on the grey ground. It is a supporting cue only: it
          // always sits next to the yellow icon block and the word WATCH, never alone.
          final exception =
              t.brightness == Brightness.light && tier == AlertTier.watch;
          if (exception) {
            expect(
              _contrast(s.rule, t.ground),
              lessThan(3.0),
              reason: 'WATCH exception is documented; remove it if this passes',
            );
          } else {
            expect(
              _contrast(s.rule, t.ground),
              greaterThanOrEqualTo(3.0),
              reason: '${s.label} rule/ground',
            );
          }
        }
        expect(
          t.tier(AlertTier.danger).rule,
          t.brightness == Brightness.light
              ? t.tier(AlertTier.danger).color
              : t.tier(AlertTier.danger).onGround,
        );
      });
    }

    test('tier field colour values are unchanged', () {
      final t = AppTokens.light;
      expect(t.tier(AlertTier.safe).color, const Color(0xFF1D6B3A));
      expect(t.tier(AlertTier.watch).color, const Color(0xFFF2C200));
      expect(t.tier(AlertTier.warning).color, const Color(0xFFB93D0B));
      expect(t.tier(AlertTier.danger).color, const Color(0xFFB3121C));
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
        // One more frame: the map refits its markers right after the offline notice appears.
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        await _teardownApp(tester);
      });
    }

    // Flutter's text-contrast check samples screenshot pixels, and thin Thai glyphs fool it
    // (it reports 1.4:1 for dark ink on white). The English UI uses the same colors, so the
    // pixel check runs there; the exact color pairs are verified in the 'tokens' group.
    const tabsEn = ['Home', 'Map', 'Call', 'Report', 'Guide'];
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
      ('โทร', 'calls'),
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

    testWidgets('night board: home and map 390x844', (tester) async {
      _setScreen(tester, const Size(390, 844));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await _pumpApp(tester);
      await expectLater(
        find.byType(DisasterApp),
        matchesGoldenFile('goldens/home_night_390x844.png'),
      );
      await tester.tap(find.text('แผนที่').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000));
      await expectLater(
        find.byType(DisasterApp),
        matchesGoldenFile('goldens/map_night_390x844.png'),
      );
      await _teardownApp(tester);
    });

    testWidgets('map sheet showing the sensor readings 390x844', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      await _pumpApp(tester);
      await tester.tap(find.text('แผนที่').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('เซนเซอร์'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(DisasterApp),
        matchesGoldenFile('goldens/map_sensors_390x844.png'),
      );
      await _teardownApp(tester);
    });

    testWidgets('settings 390x844', (tester) async {
      _setScreen(tester, const Size(390, 844));
      await _pumpApp(tester);
      await tester.tap(find.byTooltip('ตั้งค่า').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(
        find.byType(DisasterApp),
        matchesGoldenFile('goldens/settings_390x844.png'),
      );
      await _teardownApp(tester);
    });

    testWidgets('Home at danger: band and level card take the tier color', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sensors = SensorService()..simulateWater(200);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: HomeScreen(
              sensors: sensors,
              storage: storage,
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byWidgetPredicate(
          (w) => w is LevelSlab && w.level == AlertLevel.danger,
        ),
        findsOneWidget,
      );
      expect(find.byType(SosBar), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_danger_390x844.png'),
      );
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
    });

    testWidgets('Home with no live data: neutral slab, never Safe', (
      tester,
    ) async {
      _setScreen(tester, const Size(390, 844));
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sensors = SensorService(
        snapshotUrl: 'https://example.test/snapshot',
        fetcher: (_) async => throw StateError('offline'),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            body: HomeScreen(
              sensors: sensors,
              storage: storage,
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_nodata_390x844.png'),
      );
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
    });

    // Thai copy is longer than English: check it is not clipped and the slab stays neutral.
    // A bar the height of the nav bar stands in for it so the cut line is visible.
    for (final (slug, size, scale) in [
      ('390x844', const Size(390, 844), 1.0),
      ('360x640_scale1.5', const Size(360, 640), 1.5),
    ]) {
      testWidgets('Home with no live data in Thai $slug', (tester) async {
        _setScreen(tester, size, textScale: scale);
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.create();
        final sensors = SensorService(
          snapshotUrl: 'https://example.test/snapshot',
          fetcher: (_) async => throw StateError('offline'),
        );
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('th'),
            supportedLocales: const [Locale('th'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: HomeScreen(
                sensors: sensors,
                storage: storage,
                location: LocationService(
                  storage,
                  lookup: (_, _) async => null,
                ),
              ),
              bottomNavigationBar: const SizedBox(
                height: AppSize.navBar,
                child: ColoredBox(color: Colors.black12),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('ไม่มีข้อมูลสด'), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/home_nodata_th_$slug.png'),
        );
        await tester.pumpWidget(const SizedBox());
        sensors.dispose();
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
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.md),
                child: SensorReadings(sensors: sensors),
              ),
            ),
          ),
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
                    Text(sample, style: text.displayMedium),
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
