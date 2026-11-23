import 'dart:convert';

import 'package:disaster_app2/l10n/l10n.dart';
import 'package:disaster_app2/models/alert_history_entry.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/screens/alert_detail_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart' hide testWidgets;
import 'package:flutter_test/flutter_test.dart'
    as flutter_test
    show testWidgets;
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R-F10 (c): an "Ended: Replaced" detail shows the update that replaced it, when that update
// is live. The replacing alert is the one whose references contain this alert's id.
const label = 'ถูกแทนที่ด้วยประกาศใหม่';
const newHeadline = 'ฝนตกหนักมาก อัปเดต';
final t0 = DateTime.utc(2026, 11, 12, 2);
const tick = Duration(seconds: 31);

Map<String, dynamic> _notice(
  String id,
  String level,
  DateTime generated, {
  String msgType = 'Alert',
  List<String> references = const [],
  Duration expiresIn = const Duration(hours: 5),
  Map<String, String> headline = const {'th': 'ฝนตกหนัก', 'en': 'Heavy rain'},
}) => {
  'id': id,
  'sender': 'TMD',
  'status': 'Actual',
  'msgType': msgType,
  'level': level,
  'headline': headline,
  'sent': generated.subtract(const Duration(minutes: 5)).toIso8601String(),
  'expires': generated.add(expiresIn).toIso8601String(),
  'references': references,
  'areaCodes': ['TH-10'],
  'polygons': [],
};

Map<String, dynamic> _update(
  String level,
  DateTime g, {
  Duration expiresIn = const Duration(hours: 5),
}) => _notice(
  'e',
  level,
  g,
  msgType: 'Update',
  references: ['d'],
  expiresIn: expiresIn,
  headline: {'th': newHeadline, 'en': 'Heavy rain, update'},
);

String _body(DateTime g, List<Map<String, dynamic>> alerts) =>
    jsonEncode({'generatedAt': g.toIso8601String(), 'alerts': alerts});

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  var now = t0;
  var online = false;
  String? nextBody;
  late AlertService s;

  Widget app(Widget home, {bool dark = false, String lang = 'th'}) =>
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: Locale(lang),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      );

  // Opens the detail of live notice 'd' (danger), then lets a download replace it with
  // [after]. Returns with the detail showing "Ended: Replaced".
  Future<void> openReplaced(
    WidgetTester tester, {
    required List<Map<String, dynamic>> after,
    Size size = const Size(390, 844),
    double scale = 1.0,
    bool dark = false,
    String lang = 'th',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    now = t0;
    online = false;
    await storage.saveSnapshot(_body(t0, [_notice('d', 'danger', t0)]), t0);
    s = AlertService(
      storage,
      snapshotUrl: 'https://example.invalid/s.json',
      fetcher: (_) async => online ? nextBody! : throw Exception('offline'),
      clock: () => now,
    );
    s.startAutoRefresh(every: const Duration(seconds: 30));
    await tester.pumpWidget(
      app(
        AlertDetailScreen(alert: s.visibleAlerts.single, alerts: s),
        dark: dark,
        lang: lang,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final g = t0.add(const Duration(minutes: 2));
    nextBody = _body(g, after);
    online = true;
    now = g;
    await tester.pump(tick);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // The service ticks on a timer: stop it before the framework checks for pending timers.
  void testWidgets(String name, Future<void> Function(WidgetTester) body) =>
      flutter_test.testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      });

  final row = find.byKey(const ValueKey('replacement-row'));

  testWidgets('replaced DANGER notice shows the replacing alert and opens it', (
    tester,
  ) async {
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(tester, after: [_update('danger', g)]);
    expect(find.textContaining('สิ้นสุดแล้ว: ถูกแทนที่'), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    expect(row, findsOneWidget);
    final ctx = tester.element(find.byType(AlertDetailScreen));
    expect(
      find.descendant(
        of: row,
        matching: find.text(ctx.levelLabel(AlertLevel.danger)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text(newHeadline)),
      findsOneWidget,
    );
    // The row sits above the quiet tier block.
    expect(
      tester.getTopLeft(row).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('tier-block'))).dy),
    );
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
      find.byType(AlertDetailScreen, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text(newHeadline), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement is WARNING while the original was DANGER: its own '
      'tier shows', (tester) async {
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(tester, after: [_update('warning', g)]);
    final ctx = tester.element(find.byType(AlertDetailScreen));
    expect(
      find.descendant(
        of: row,
        matching: find.text(ctx.levelLabel(AlertLevel.warning)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text(ctx.levelLabel(AlertLevel.danger)),
      ),
      findsNothing,
    );
  });

  testWidgets('semantics tap on the row opens the replacing alert', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(tester, after: [_update('danger', g)]);
    tester.semantics.tap(find.semantics.byLabel(RegExp(newHeadline)));
    await tester.pumpAndSettle();
    expect(
      find.byType(AlertDetailScreen, skipOffstage: false),
      findsNWidgets(2),
    );
    handle.dispose();
  });

  testWidgets('replacement expired later: no row', (tester) async {
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(
      tester,
      after: [_update('danger', g, expiresIn: const Duration(minutes: 5))],
    );
    expect(row, findsOneWidget);
    now = g.add(const Duration(minutes: 6));
    await tester.pump(tick);
    await tester.pump();
    expect(find.textContaining('สิ้นสุดแล้ว: ถูกแทนที่'), findsOneWidget);
    expect(row, findsNothing);
    expect(find.text(label), findsNothing);
  });

  testWidgets('replacement cancelled later: no row', (tester) async {
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(tester, after: [_update('danger', g)]);
    expect(row, findsOneWidget);
    final g2 = g.add(const Duration(minutes: 2));
    nextBody = _body(g2, [
      _notice('c', 'danger', g2, msgType: 'Cancel', references: ['e']),
    ]);
    now = g2;
    await tester.pump(tick);
    await tester.pump();
    expect(find.textContaining('สิ้นสุดแล้ว: ถูกแทนที่'), findsOneWidget);
    expect(row, findsNothing);
  });

  testWidgets('replacing alert not in the list: no row', (tester) async {
    final g = t0.add(const Duration(minutes: 2));
    // Only a Cancel of d: ended, but nothing replaced it.
    await openReplaced(
      tester,
      after: [
        _notice('c', 'danger', g, msgType: 'Cancel', references: ['d']),
      ],
    );
    expect(find.textContaining('สิ้นสุดแล้ว: ยกเลิก'), findsOneWidget);
    expect(row, findsNothing);
  });

  testWidgets('opened from history: no row even if the update is live', (
    tester,
  ) async {
    final g = t0.add(const Duration(minutes: 2));
    await openReplaced(tester, after: [_update('danger', g)]);
    final entry = s.history.single;
    expect(entry.reason, EndReason.replaced);
    final old = OfficialAlert.fromJson(_notice('d', 'danger', t0));
    await tester.pumpWidget(
      app(AlertDetailScreen(alert: old, alerts: s, ended: entry)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('สิ้นสุดแล้ว: ถูกแทนที่'), findsOneWidget);
    expect(row, findsNothing);
  });

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    for (final scale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        testWidgets('no overflow ${size.width.toInt()}x${size.height.toInt()} '
            'scale $scale ${dark ? "dark" : "light"}', (tester) async {
          final g = t0.add(const Duration(minutes: 2));
          await openReplaced(
            tester,
            after: [_update('danger', g)],
            size: size,
            scale: scale,
            dark: dark,
          );
          expect(row, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
