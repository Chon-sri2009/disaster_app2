import 'dart:convert';

import 'package:disaster_app2/l10n/l10n.dart';
import 'package:disaster_app2/models/alert_history_entry.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/screens/alert_detail_screen.dart';
import 'package:disaster_app2/screens/alert_history_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

const _url = 'https://example.invalid/alerts';

Map<String, dynamic> _a(
  String id, {
  String msgType = 'Alert',
  String status = 'Actual',
  String level = 'warning',
  String sent = '2026-11-12T01:00:00Z',
  String? expires = '2026-11-12T05:00:00Z',
  List<String> refs = const [],
  List<String> codes = const ['TH-10'],
}) => {
  'id': id,
  'sender': 'TMD',
  'status': status,
  'msgType': msgType,
  'level': level,
  'headline': {'th': 'ฝนตกหนัก $id', 'en': 'Heavy rain $id'},
  'sent': sent,
  'expires': expires,
  'references': refs,
  'areaCodes': codes,
  'polygons': [],
};

String _snap(
  List<Map<String, dynamic>> alerts,
  DateTime generated, {
  int skipped = 0,
}) => jsonEncode({
  'generatedAt': generated.toUtc().toIso8601String(),
  'skippedFiles': skipped,
  'alerts': alerts,
});

// Persisting alerts is non-critical: every write fails here.
class _ThrowingStorage implements StorageService {
  _ThrowingStorage(this._real);
  final StorageService _real;

  @override
  Future<void> saveTrackedAlerts(List<Map<String, dynamic>> records) async =>
      throw Exception('disk full');

  @override
  Future<void> saveAlertHistory(List<Map<String, dynamic>> entries) async =>
      throw Exception('disk full');

  @override
  List<Map<String, dynamic>> get trackedAlerts => _real.trackedAlerts;

  @override
  List<Map<String, dynamic>> get alertHistory => _real.alertHistory;

  @override
  ({String json, DateTime fetchedAt})? get snapshot => _real.snapshot;

  @override
  Future<void> saveSnapshot(String json, DateTime fetchedAt) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late StorageService storage;
  var now = DateTime.utc(2026, 11, 12, 2);
  String? next;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    now = DateTime.utc(2026, 11, 12, 2);
    next = null;
  });

  AlertService make() => AlertService(
    storage,
    snapshotUrl: _url,
    fetcher: (_) async => next!,
    clock: () => now,
  );

  Future<void> feed(
    AlertService s,
    List<Map<String, dynamic>> alerts, {
    int skipped = 0,
  }) async {
    next = _snap(alerts, now, skipped: skipped);
    await s.refresh();
  }

  group('recording', () {
    test('cancelled by an Actual Cancel -> Cancelled', () async {
      final s = make();
      await feed(s, [_a('a')]);
      expect(s.history, isEmpty);
      now = now.add(const Duration(minutes: 5));
      await feed(s, [
        _a('c', msgType: 'Cancel', refs: ['a']),
      ]);
      expect(s.history.map((e) => e.record.id), ['a']);
      expect(s.history.single.reason, EndReason.cancelled);
    });

    test('replaced by an Actual Update -> Replaced', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = now.add(const Duration(minutes: 5));
      await feed(s, [
        _a('u', msgType: 'Update', refs: ['a']),
      ]);
      expect(s.history.single.reason, EndReason.replaced);
      expect(s.history.single.record.id, 'a');
    });

    test('a Test Cancel is no evidence', () async {
      final s = make();
      await feed(s, [_a('a')]);
      await feed(s, [
        _a('a'),
        _a('c', msgType: 'Cancel', status: 'Test', refs: ['a']),
      ]);
      expect(s.history, isEmpty);
    });

    test('past expiry -> Expired, ended at the expiry time', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 5, 1);
      await feed(s, []);
      expect(s.history.single.reason, EndReason.expired);
      expect(s.history.single.endedAt, DateTime.utc(2026, 11, 12, 5));
    });

    test('vanished with no proof is not recorded and stays tracked', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = now.add(const Duration(minutes: 5));
      await feed(s, []);
      expect(s.history, isEmpty);
      expect(storage.trackedAlerts.map((r) => r['id']), ['a']);
      // Proof arrives later: still recorded.
      now = now.add(const Duration(minutes: 5));
      await feed(s, [
        _a('c', msgType: 'Cancel', refs: ['a']),
      ]);
      expect(s.history.single.reason, EndReason.cancelled);
    });

    test('unproven vanish is dropped silently after 7 days', () async {
      final s = make();
      await feed(s, [_a('a', expires: '2027-01-01T00:00:00Z')]);
      now = now.add(const Duration(minutes: 5));
      await feed(s, []);
      now = now.add(const Duration(days: 7, minutes: 1));
      await feed(s, []);
      expect(s.history, isEmpty);
      expect(storage.trackedAlerts, isEmpty);
    });

    test('skippedFiles > 0 never ends anything', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, [], skipped: 1);
      expect(s.history, isEmpty);
      expect(storage.trackedAlerts.map((r) => r['id']), ['a']);
      await feed(s, []);
      expect(s.history.single.reason, EndReason.expired);
    });

    test('an alert ends once', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, []);
      await feed(s, [_a('a')]);
      await feed(s, []);
      expect(s.history, hasLength(1));
    });

    test('capped at 50, newest first', () async {
      final s = make();
      final ids = [for (var i = 0; i < 55; i++) 'x$i'];
      await feed(s, [
        for (final id in ids) _a(id, expires: '2026-11-12T03:00:00Z'),
      ]);
      now = DateTime.utc(2026, 11, 12, 4);
      await feed(s, []);
      expect(s.history, hasLength(50));
      expect(s.history.first.endedAt.isBefore(s.history.last.endedAt), isFalse);
    });

    test('entries older than 30 days are pruned', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, []);
      expect(s.history, hasLength(1));
      now = now.add(const Duration(days: 31));
      await feed(s, []);
      expect(s.history, isEmpty);
    });
  });

  group('persistence and isolation', () {
    test('survives a restart; alert pruned meanwhile -> Expired', () async {
      final s = make();
      await feed(s, [_a('a')]);
      s.dispose();
      // App closed for a day; the backend no longer lists the alert.
      now = now.add(const Duration(days: 1));
      next = _snap([], now);
      final again = make();
      await again.refresh();
      expect(again.history.single.reason, EndReason.expired);
      // Another restart still has it.
      final third = make();
      expect(third.history.single.record.id, 'a');
    });

    test('history never enters visibleAlerts or levelAt', () async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, []);
      expect(s.history, hasLength(1));
      expect(s.visibleAlerts, isEmpty);
      expect(
        s.levelAt(const LatLng(13.5, 100.5), provinceCode: 'TH-10'),
        AlertLevel.safe,
      );
    });

    test('corrupt stored JSON gives empty history', () async {
      SharedPreferences.setMockInitialValues({
        'alert_history': 'not json {',
        'alert_tracked': '[1,2,3]',
      });
      storage = await StorageService.create();
      final s = make();
      expect(s.history, isEmpty);
      await feed(s, [_a('a')]);
      expect(s.history, isEmpty);
    });

    test('one bad stored entry is skipped, good ones kept', () async {
      final good = HistoryEntry(
        record: AlertRecord.of(OfficialAlert.fromJson(_a('g'))),
        endedAt: now.subtract(const Duration(hours: 1)),
        reason: EndReason.expired,
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode([
          {'junk': true},
          good,
        ]),
      });
      storage = await StorageService.create();
      expect(make().history.map((e) => e.record.id), ['g']);
    });
  });

  group('hardening', () {
    test('record keeps hadPolygons; old records default to false', () {
      final withShape = OfficialAlert.fromJson({
        ..._a('p', codes: []),
        'polygons': [
          [
            [100.0, 13.0],
            [101.0, 13.0],
            [101.0, 14.0],
          ],
        ],
      });
      final r = AlertRecord.of(withShape);
      expect(r.hadPolygons, isTrue);
      expect(AlertRecord.fromJson(r.toJson()).hadPolygons, isTrue);
      final old = r.toJson()..remove('hadPolygons');
      expect(AlertRecord.fromJson(old).hadPolygons, isFalse);
      expect(
        AlertRecord.of(OfficialAlert.fromJson(_a('c'))).hadPolygons,
        isFalse,
      );
    });

    test('a failing storage write does not break refresh', () async {
      final bad = _ThrowingStorage(storage);
      final s = AlertService(
        bad,
        snapshotUrl: _url,
        fetcher: (_) async => next!,
        clock: () => now,
      );
      next = _snap([_a('a')], now);
      await s.refresh();
      expect(s.visibleAlerts.map((a) => a.id), ['a']);
      await Future<void>.delayed(Duration.zero);
      s.dispose();
    });

    test('stored history is pruned, capped and sorted on load', () async {
      final entries = [
        for (var i = 0; i < 60; i++)
          HistoryEntry(
            record: AlertRecord.of(OfficialAlert.fromJson(_a('h$i'))),
            // Every third entry is older than 30 days; order is scrambled.
            endedAt: now.subtract(
              i % 3 == 0
                  ? Duration(days: 31 + i)
                  : Duration(hours: (i * 7) % 60 + 1),
            ),
            reason: EndReason.expired,
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode(entries),
      });
      storage = await StorageService.create();
      final h = make().history;
      expect(h, hasLength(40));
      expect(
        h.every((e) => now.difference(e.endedAt) <= AlertService.historyKeep),
        isTrue,
      );
      for (var i = 1; i < h.length; i++) {
        expect(h[i - 1].endedAt.isBefore(h[i].endedAt), isFalse);
      }
    });

    test('load caps at 50', () async {
      final entries = [
        for (var i = 0; i < 60; i++)
          HistoryEntry(
            record: AlertRecord.of(OfficialAlert.fromJson(_a('h$i'))),
            endedAt: now.subtract(Duration(minutes: i + 1)),
            reason: EndReason.expired,
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        'alert_history': jsonEncode(entries),
      });
      storage = await StorageService.create();
      final h = make().history;
      expect(h, hasLength(50));
      expect(h.first.record.id, 'h0');
    });
  });

  group('screen', () {
    Widget app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: home,
      ),
    );

    setUpAll(() async {
      await loadAppFonts();
    });

    testWidgets('empty state does not say safe', (tester) async {
      final s = make();
      await tester.pumpWidget(app(AlertHistoryScreen(alerts: s)));
      expect(find.text('No ended alerts yet'), findsOneWidget);
      expect(
        find.textContaining(RegExp('safe', caseSensitive: false)),
        findsNothing,
      );
      s.dispose();
    });

    testWidgets('row shows reason and opens the detail screen', (tester) async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, []);
      await tester.pumpWidget(app(AlertHistoryScreen(alerts: s)));
      expect(find.text('Heavy rain a'), findsOneWidget);
      expect(find.textContaining('Expired'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Heavy rain a'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      s.dispose();
    });

    testWidgets('detail from history says Ended, hides live-only parts', (
      tester,
    ) async {
      final s = make();
      await feed(s, [_a('a')]);
      now = DateTime.utc(2026, 11, 12, 6);
      await feed(s, []);
      await tester.pumpWidget(app(AlertHistoryScreen(alerts: s)));
      await tester.tap(find.text('Heavy rain a'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(AlertDetailScreen));
      final endedAt = s.history.single.endedAt;
      expect(
        find.textContaining('Ended: Expired · ${ctx.stamp(endedAt)}'),
        findsOneWidget,
      );
      expect(find.textContaining('Alerts last updated'), findsNothing);
      expect(find.text('Received by the app'), findsNothing);
      s.dispose();
    });

    testWidgets('history detail of a polygon notice does not say not given', (
      tester,
    ) async {
      final s = make();
      final entry = HistoryEntry(
        record: AlertRecord.of(
          OfficialAlert.fromJson({
            ..._a('p', codes: []),
            'polygons': [
              [
                [100.0, 13.0],
                [101.0, 13.0],
                [101.0, 14.0],
              ],
            ],
          }),
        ),
        endedAt: now,
        reason: EndReason.expired,
      );
      await tester.pumpWidget(
        app(
          AlertDetailScreen(
            alert: entry.record.toAlert(),
            alerts: s,
            ended: entry,
          ),
        ),
      );
      expect(
        find.text('Area was given as a map shape (not kept in history)'),
        findsOneWidget,
      );
      expect(find.text('Area not given'), findsNothing);
      s.dispose();
    });
  });
}
