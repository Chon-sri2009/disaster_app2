import 'dart:convert';

import 'package:disaster_app2/l10n/l10n.dart';
import 'package:disaster_app2/models/alert_history_entry.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/damage_report.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/screens/about_screen.dart';
import 'package:disaster_app2/screens/alert_detail_screen.dart';
import 'package:disaster_app2/screens/alert_history_screen.dart';
import 'package:disaster_app2/screens/flood_history_card.dart';
import 'package:disaster_app2/screens/report_screen.dart';
import 'package:disaster_app2/screens/settings_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/flood_history_service.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';
import 'package:disaster_app2/widgets/sensor_readings.dart';
import 'package:disaster_app2/widgets/soft_ui.dart';
import 'package:disaster_app2/widgets/warning_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R6 and R9: the Report form, Settings, About, alert detail, alert history, the flood-history
// block, sensor readings and the banner, all in the Posted notice style. These tests check the
// style rules (no cards, no shadows, no discs, 48 dp targets, no overflow at 1.5x Thai) and the
// few things the redesign must keep (the "not sent" line above Save, a check on the chosen
// category, the tier word on an alert).

const _longThai =
    'ประกาศเตือนภัยฝนตกหนักถึงหนักมากและน้ำท่วมฉับพลัน ระดับน้ำสูงผิดปกติ โปรดเตรียมพร้อมอพยพ';

Map<String, dynamic> _alertJson(
  String id, {
  String level = 'warning',
  Map<String, String>? headline,
}) => {
  'id': id,
  'sender': 'TMD',
  'status': 'Actual',
  'msgType': 'Alert',
  'level': level,
  'headline': headline ?? {'th': 'ฝนตกหนัก $id', 'en': 'Heavy rain $id'},
  'sent': DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String(),
  'expires': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 3))
      .toIso8601String(),
  'references': <String>[],
  'areaCodes': ['TH-10', 'TH-99'],
  'polygons': <Object>[],
};

class _Rig {
  _Rig(this.tester, this.size, this.scale, this.dark);

  final WidgetTester tester;
  final Size size;
  final double scale;
  final bool dark;
  final List<void Function()> _disposers = [];

  Future<StorageService> storage([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return StorageService.create();
  }

  void own(void Function() dispose) => _disposers.add(dispose);

  Future<void> show(Widget home, {String lang = 'th'}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: Locale(lang),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: home,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox());
    for (final d in _disposers) {
      d();
    }
  }
}

// The Posted notice rules every migrated screen must meet.
void _expectNoticeStyle(WidgetTester tester, {String? reason}) {
  expect(tester.takeException(), isNull, reason: reason);
  for (final type in [Card, ExpansionTile, SoftCard, SoftTile, AccentRow]) {
    expect(find.byType(type), findsNothing, reason: '$type $reason');
  }
  expect(find.byType(StatusPill), findsNothing, reason: reason);
  expect(find.byType(BrandHeader), findsNothing, reason: reason);
  final shadowed = find.byWidgetPredicate((w) {
    if (w is! DecoratedBox) return false;
    final d = w.decoration;
    return d is BoxDecoration &&
        ((d.boxShadow?.isNotEmpty ?? false) || d.shape == BoxShape.circle);
  });
  expect(shadowed, findsNothing, reason: 'no shadow or disc $reason');
  final taps = find.byWidgetPredicate((w) => w is InkWell && w.onTap != null);
  for (final e in taps.evaluate()) {
    final box = e.renderObject! as RenderBox;
    expect(
      box.size.height,
      greaterThanOrEqualTo(AppSize.tapTarget - 0.01),
      reason: 'tap target height $reason',
    );
    expect(
      box.size.width,
      greaterThanOrEqualTo(AppSize.tapTarget - 0.01),
      reason: 'tap target width $reason',
    );
  }
}

typedef _Build = Future<Widget> Function(_Rig rig);

AlertService _alertsFor(_Rig rig, StorageService storage) {
  final s = AlertService(storage);
  rig.own(s.dispose);
  return s;
}

Map<String, _Build> _screens() => {
  'report': (rig) async {
    final storage = await rig.storage();
    await storage.addReport(
      DamageReport(
        id: '1',
        category: 'flooded_road',
        note: _longThai,
        createdAt: DateTime.now(),
        address: 'ถนนสุขุมวิท กรุงเทพมหานคร',
      ),
    );
    return Scaffold(
      body: ReportScreen(
        storage: storage,
        location: LocationService(storage, lookup: (_, _) async => null),
      ),
    );
  },
  'settings': (rig) async => SettingsScreen(storage: await rig.storage()),
  'about': (rig) async => const AboutScreen(),
  'alert detail': (rig) async {
    final storage = await rig.storage();
    return AlertDetailScreen(
      alert: OfficialAlert.fromJson(
        _alertJson('a', headline: {'th': _longThai, 'en': 'Heavy rain ' * 8}),
      ),
      alerts: _alertsFor(rig, storage),
    );
  },
  'alert history': (rig) async {
    final now = DateTime.now().toUtc();
    final storage = await rig.storage({
      'alert_history': jsonEncode([
        for (final (i, level) in ['warning', 'watch', 'danger'].indexed)
          HistoryEntry(
            record: AlertRecord.of(
              OfficialAlert.fromJson(
                _alertJson(
                  'h$i',
                  level: level,
                  headline: {'th': _longThai, 'en': 'Heavy rain ' * 8},
                ),
              ),
            ),
            endedAt: now.subtract(Duration(hours: i + 1)),
            reason: EndReason.values[i],
          ).toJson(),
      ]),
    });
    return AlertHistoryScreen(alerts: _alertsFor(rig, storage));
  },
  'flood history': (rig) async {
    final storage = await rig.storage();
    await storage.saveLastPosition(const LatLng(13.75, 100.5));
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.md),
        child: FloodHistoryCard(
          storage: storage,
          service: FloodHistoryService(
            snapshotUrl: 'https://example.invalid/snapshot',
            fetcher: (_) async => jsonEncode({
              'found': true,
              'district': 'พระนคร',
              'province': 'กรุงเทพมหานคร',
              'years': [
                for (var y = 2011; y <= 2020; y++)
                  {'year': y, 'freq': y.isEven ? 1 : 0},
              ],
            }),
          ),
        ),
      ),
    );
  },
  'sensors demo': (rig) async {
    final sensors = SensorService()..simulateWater(200);
    rig.own(sensors.dispose);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.md),
        child: SensorReadings(sensors: sensors),
      ),
    );
  },
  'sensors live': (rig) async {
    final sensors = SensorService(
      snapshotUrl: 'https://example.invalid/snapshot',
      fetcher: (_) async => jsonEncode({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'stations': [
          {
            'id': 'a',
            'name': 'สถานีคลองประปาเหนือสะพานพระรามหก',
            'band': 'warning',
            'status': 'ok',
            'waterCm': 120,
            'readingTime': DateTime.now().toUtc().toIso8601String(),
          },
          {'id': 'b', 'name': 'สถานี B', 'band': 'unknown', 'status': 'stale'},
        ],
      }),
    );
    rig.own(sensors.dispose);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.md),
        child: SensorReadings(sensors: sensors),
      ),
    );
  },
  'banners': (rig) async => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final kind in BannerKind.values) ...[
            WarningBanner(
              kind: kind,
              message: _longThai,
              actionLabel: 'ลองอีกครั้ง',
              onAction: () {},
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ],
      ),
    ),
  ),
};

void main() {
  setUpAll(loadAppFonts);

  group('Posted notice rules on every migrated screen', () {
    for (final entry in _screens().entries) {
      for (final size in const [Size(360, 640), Size(390, 844)]) {
        for (final scale in const [1.0, 1.5]) {
          for (final dark in const [false, true]) {
            testWidgets(
              '${entry.key} ${size.width.toInt()}x${size.height.toInt()} '
              'x$scale ${dark ? 'dark' : 'light'}',
              (tester) async {
                final rig = _Rig(tester, size, scale, dark);
                await rig.show(await entry.value(rig));
                _expectNoticeStyle(tester, reason: entry.key);
                await rig.finish();
              },
            );
          }
        }
      }
    }
  });

  group('Report', () {
    for (final c in const {
      'th': 'บันทึกในเครื่องนี้เท่านั้น ไม่มีใครได้รับแจ้ง',
      'en': 'Saved on this phone only. No one is told.',
    }.entries) {
      testWidgets('"not sent" sits above Save at 360x640 x1.5 (${c.key})', (
        tester,
      ) async {
        final rig = _Rig(tester, const Size(360, 640), 1.5, false);
        final storage = await rig.storage();
        await rig.show(
          Scaffold(
            body: ReportScreen(
              storage: storage,
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
          lang: c.key,
        );
        final save = find.byIcon(Icons.save);
        await tester.ensureVisible(save);
        await tester.pump();
        final line = find.text(c.value);
        expect(line, findsOneWidget);
        expect(
          tester.getBottomLeft(line).dy,
          lessThanOrEqualTo(tester.getTopLeft(save).dy),
        );
        // Save is a full-width bar at least 56 dp tall.
        final bar = find.ancestor(
          of: save,
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(
          tester.getSize(bar).height,
          greaterThanOrEqualTo(AppSize.primaryButton),
        );
        expect(
          tester.getSize(bar).width,
          greaterThanOrEqualTo(360 - 2 * AppSpace.md - 0.01),
        );
        expect(tester.takeException(), isNull);
        await rig.finish();
      });
    }

    testWidgets('a chosen category shows a check icon and its word', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      final storage = await rig.storage();
      await rig.show(
        Scaffold(
          body: ReportScreen(
            storage: storage,
            location: LocationService(storage, lookup: (_, _) async => null),
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNothing);
      await tester.tap(find.text('ถนนน้ำท่วม'));
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('ถนนน้ำท่วม'), findsOneWidget);
      await tester.tap(find.text('ไฟฟ้าดับ'));
      await tester.pump();
      // Only the latest choice is marked.
      expect(find.byIcon(Icons.check), findsOneWidget);
      await rig.finish();
    });

    testWidgets('saving without a category shows the error word, not red alone', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      final storage = await rig.storage();
      await rig.show(
        Scaffold(
          body: ReportScreen(
            storage: storage,
            location: LocationService(storage, lookup: (_, _) async => null),
          ),
        ),
      );
      final save = find.byIcon(Icons.save);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('กรุณาเลือกประเภท'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await rig.finish();
    });
  });

  group('Alert detail', () {
    for (final level in AlertLevel.values) {
      testWidgets('tier word and block for $level sit above the headline', (
        tester,
      ) async {
        final rig = _Rig(tester, const Size(360, 640), 1.5, false);
        final storage = await rig.storage();
        await rig.show(
          AlertDetailScreen(
            alert: OfficialAlert.fromJson(
              _alertJson('a', level: level.name),
            ),
            alerts: _alertsFor(rig, storage),
          ),
        );
        final ctx = tester.element(find.byType(AlertDetailScreen));
        final t = ctx.tokens;
        final style = t.styleFor(level);
        final word = find.text(ctx.levelLabel(level));
        expect(word, findsOneWidget);
        expect(find.byIcon(style.icon), findsWidgets);
        final block = tester.widget<Container>(
          find.byKey(const ValueKey('tier-block')),
        );
        final d = block.decoration! as BoxDecoration;
        final loud = level == AlertLevel.warning || level == AlertLevel.danger;
        expect(d.color, loud ? style.color : t.ground);
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('tier-block'))).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('ฝนตกหนัก a')).dy),
        );
        await rig.finish();
      });
    }

    for (final level in [AlertLevel.danger, AlertLevel.warning]) {
      testWidgets('an ended $level notice is not filled with the tier colour', (
        tester,
      ) async {
        final rig = _Rig(tester, const Size(390, 844), 1.0, false);
        final storage = await rig.storage();
        final entry = HistoryEntry(
          record: AlertRecord.of(
            OfficialAlert.fromJson(_alertJson('e', level: level.name)),
          ),
          endedAt: DateTime.now().toUtc(),
          reason: EndReason.expired,
        );
        await rig.show(
          AlertDetailScreen(
            alert: entry.record.toAlert(),
            alerts: _alertsFor(rig, storage),
            ended: entry,
          ),
        );
        final ctx = tester.element(find.byType(AlertDetailScreen));
        final t = ctx.tokens;
        final style = t.styleFor(level);
        final d =
            tester
                    .widget<Container>(find.byKey(const ValueKey('tier-block')))
                    .decoration!
                as BoxDecoration;
        expect(d.color, t.ground, reason: 'ended is quiet');
        expect((d.border! as Border).top.color, style.rule);
        expect(find.text(ctx.levelLabel(level)), findsOneWidget);
        expect(find.byIcon(style.icon), findsWidgets);
        await rig.finish();
      });
    }

    testWidgets('a notice read from history is still a plain record', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      final storage = await rig.storage();
      final entry = HistoryEntry(
        record: AlertRecord.of(OfficialAlert.fromJson(_alertJson('e'))),
        endedAt: DateTime.now().toUtc(),
        reason: EndReason.cancelled,
      );
      await rig.show(
        AlertDetailScreen(
          alert: entry.record.toAlert(),
          alerts: _alertsFor(rig, storage),
          ended: entry,
        ),
      );
      expect(find.textContaining('สิ้นสุดแล้ว: ยกเลิก'), findsOneWidget);
      _expectNoticeStyle(tester);
      await rig.finish();
    });
  });

  group('Alert history', () {
    testWidgets('rows carry the tier as an outlined tag, never a filled one', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      final build = _screens()['alert history']!;
      await rig.show(await build(rig));
      final tags = tester.widgetList<Tag>(find.byType(Tag)).toList();
      expect(tags, hasLength(3));
      for (final tag in tags) {
        expect(tag.onColor, isNull, reason: 'history never shouts a level');
        expect(tag.icon, isNotNull);
      }
      expect(find.textContaining('ไม่ใช่สถานะปัจจุบัน'), findsOneWidget);
      await rig.finish();
    });
  });

  group('Settings', () {
    testWidgets('the chosen language and theme are marked with a check', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(360, 640), 1.5, false);
      final storage = await rig.storage();
      await rig.show(SettingsScreen(storage: storage));
      // One for the language, one for the theme.
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(storage.language.code, 'en');
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      await rig.finish();
    });
  });

  group('WarningBanner', () {
    testWidgets('offline is neutral with a cloud icon, never red', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      await rig.show(
        const Scaffold(
          body: WarningBanner(kind: BannerKind.offline, message: 'x'),
        ),
      );
      final t = AppTokens.light;
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(WarningBanner),
          matching: find.byType(DecoratedBox),
        ),
      );
      final d = box.decoration as BoxDecoration;
      expect(d.color, t.offlineBg);
      expect((d.border as Border?)?.top.color, isNot(t.dangerInk));
      await rig.finish();
    });

    testWidgets('error is errorBg with a dangerInk outline and an icon', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      await rig.show(
        const Scaffold(
          body: WarningBanner(kind: BannerKind.error, message: 'x'),
        ),
      );
      final t = AppTokens.light;
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(WarningBanner),
          matching: find.byType(DecoratedBox),
        ),
      );
      final d = box.decoration as BoxDecoration;
      expect(d.color, t.errorBg);
      expect((d.border as Border).top.color, t.dangerInk);
      await rig.finish();
    });
  });

  group('Sensor readings', () {
    testWidgets('the debug simulator folds open without an ExpansionTile', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(360, 640), 1.5, false);
      final build = _screens()['sensors demo']!;
      await rig.show(await build(rig));
      expect(find.byType(Slider), findsNothing);
      final toggle = find.text('ทดลอง: จำลองระดับน้ำ');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Slider), findsOneWidget);
      _expectNoticeStyle(tester);
      await rig.finish();
    });

    testWidgets('a station with no reading shows a dash and an icon, not a tier', (
      tester,
    ) async {
      final rig = _Rig(tester, const Size(390, 844), 1.0, false);
      final build = _screens()['sensors live']!;
      await rig.show(await build(rig));
      expect(find.byIcon(Icons.sensors_off), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
      await rig.finish();
    });
  });
}
