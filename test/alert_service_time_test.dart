import 'dart:convert';

import 'package:disaster_app2/models/alert_history_entry.dart';
import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R-F4: stale and expiry change with the clock alone, so listeners must hear about them
// on the auto-refresh tick, once per change, even when nothing can be downloaded.
const url = 'https://example.invalid/s.json';
final t0 = DateTime.utc(2026, 11, 12, 2);
const every = Duration(minutes: 2);

// A Danger alert for the whole test square that expires [expiresIn] after [generated].
String snapshot(
  DateTime generated, {
  Duration expiresIn = const Duration(minutes: 10),
}) => jsonEncode({
  'generatedAt': generated.toIso8601String(),
  'alerts': [
    {
      'id': 'd',
      'sender': 'TMD',
      'status': 'Actual',
      'msgType': 'Alert',
      'level': 'danger',
      'headline': {'th': 'หัวข้อ d', 'en': 'Headline d'},
      'sent': generated.subtract(const Duration(minutes: 5)).toIso8601String(),
      'expires': generated.add(expiresIn).toIso8601String(),
      'areaCodes': <String>[],
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
});

final inside = LatLng(13.5, 100.5);

// Live mode with a backend that cannot be reached: no sensor data, so never a Safe slab.
// (A bare SensorService() is demo mode in tests and would show fake readings.)
SensorService offlineSensors() => SensorService(
  snapshotUrl: url,
  fetcher: (_) async => throw Exception('offline'),
);

void main() {
  late StorageService storage;
  var now = t0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    now = t0;
    await storage.saveSnapshot(snapshot(t0), t0);
  });

  // The cached snapshot is applied in the constructor, before any listener is added.
  AlertService make({
    String snapshotUrl = '',
    Future<String> Function(Uri)? fetcher,
  }) => AlertService(
    storage,
    snapshotUrl: snapshotUrl,
    fetcher: fetcher,
    clock: () => now,
  );

  testWidgets('a notice that expires while offline notifies once', (
    tester,
  ) async {
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => throw Exception('offline'),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    expect(s.visibleAlerts, hasLength(1));
    s.startAutoRefresh(every: every);
    now = t0.add(const Duration(minutes: 11));
    await tester.pump(every);
    expect(notifies, 1);
    expect(s.visibleAlerts, isEmpty);
    expect(s.levelAt(inside), AlertLevel.safe);
    await tester.pump(every);
    expect(notifies, 1);
    s.dispose();
  });

  testWidgets('no cache: the first tick does not notify without a change', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => throw Exception('offline'),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    s.startAutoRefresh(every: every);
    await tester.pump(every);
    expect(notifies, 0);
    await tester.pump(every);
    expect(notifies, 0);
    s.dispose();
  });

  testWidgets('going stale notifies once', (tester) async {
    // Long-lived alert, so only staleness changes.
    await storage.saveSnapshot(
      snapshot(t0, expiresIn: const Duration(hours: 5)),
      t0,
    );
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => throw Exception('offline'),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    s.startAutoRefresh(every: every);
    expect(s.isStale, isFalse);
    now = t0.add(const Duration(minutes: 31));
    await tester.pump(every);
    expect(notifies, 1);
    expect(s.isStale, isTrue);
    await tester.pump(every);
    expect(notifies, 1);
    s.dispose();
  });

  testWidgets('nothing changes: no extra notifies', (tester) async {
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => throw Exception('offline'),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    s.startAutoRefresh(every: every);
    for (var i = 0; i < 4; i++) {
      await tester.pump(every);
    }
    expect(notifies, 0);
    s.dispose();
  });

  testWidgets('failed fetch after a good snapshot: one notify when stale', (
    tester,
  ) async {
    await storage.saveSnapshot(
      snapshot(t0, expiresIn: const Duration(hours: 5)),
      t0,
    );
    var fail = false;
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => fail
          ? throw Exception('offline')
          : snapshot(t0, expiresIn: const Duration(hours: 5)),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    await s.refresh();
    expect(notifies, 1); // the good download itself
    fail = true;
    s.startAutoRefresh(every: every);
    await tester.pump(every);
    await tester.pump();
    expect(notifies, 1);
    now = t0.add(const Duration(minutes: 31));
    await tester.pump(every);
    await tester.pump();
    expect(notifies, 2);
    expect(s.isStale, isTrue);
    s.dispose();
  });

  testWidgets('recovery: next good download notifies once and is fresh', (
    tester,
  ) async {
    await storage.saveSnapshot(
      snapshot(t0, expiresIn: const Duration(hours: 5)),
      t0,
    );
    var online = false;
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => online
          ? snapshot(now, expiresIn: const Duration(hours: 5))
          : throw Exception('offline'),
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    s.startAutoRefresh(every: every);
    now = t0.add(const Duration(minutes: 31));
    await tester.pump(every);
    await tester.pump();
    expect(notifies, 1);
    expect(s.isStale, isTrue);
    online = true;
    now = now.add(every);
    await tester.pump(every);
    await tester.pump();
    expect(notifies, 2);
    expect(s.isStale, isFalse);
    // Back offline: a fresh snapshot ages without a further notify until it changes.
    online = false;
    await tester.pump(every);
    await tester.pump();
    expect(notifies, 2);
    s.dispose();
  });

  testWidgets('no URL: a cached snapshot still ages and expires', (
    tester,
  ) async {
    final s = make(); // no snapshot URL, refresh() does nothing
    var notifies = 0;
    s.addListener(() => notifies++);
    s.startAutoRefresh(every: every);
    now = t0.add(const Duration(minutes: 11));
    await tester.pump(every);
    expect(notifies, 1);
    expect(s.visibleAlerts, isEmpty);
    now = t0.add(const Duration(minutes: 31));
    await tester.pump(every);
    expect(notifies, 2);
    expect(s.isStale, isTrue);
    s.dispose();
  });

  // R-F6: the phone clock moved back after the data time: the age is unknown, so stale.
  group('clock moved backwards (R-F6)', () {
    setUp(() async {
      await storage.saveSnapshot(
        snapshot(t0, expiresIn: const Duration(hours: 5)),
        t0,
      );
    });

    testWidgets('1 h back: stale, one notify; restored: fresh, one notify', (
      tester,
    ) async {
      final s = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      var notifies = 0;
      s.addListener(() => notifies++);
      s.startAutoRefresh(every: every);
      expect(s.isStale, isFalse);
      now = t0.subtract(const Duration(hours: 1));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isTrue);
      expect(notifies, 1);
      await tester.pump(every);
      await tester.pump();
      expect(notifies, 1);
      now = t0.add(const Duration(minutes: 1));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isFalse);
      expect(notifies, 2);
      s.dispose();
    });

    testWidgets('30 s back (within slack): not stale, no notify', (
      tester,
    ) async {
      final s = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      var notifies = 0;
      s.addListener(() => notifies++);
      s.startAutoRefresh(every: every);
      now = t0.subtract(const Duration(seconds: 30));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isFalse);
      expect(notifies, 0);
      s.dispose();
    });

    // R-F10 (a): alert data tolerates a clock up to 5 min back; 1 h back is still stale.
    testWidgets('4 min back (within the 5 min slack): not stale, no notify', (
      tester,
    ) async {
      final s = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      var notifies = 0;
      s.addListener(() => notifies++);
      s.startAutoRefresh(every: every);
      now = t0.subtract(const Duration(minutes: 4));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isFalse);
      expect(notifies, 0);
      s.dispose();
    });

    testWidgets('6 min back (past the slack): stale, one notify', (
      tester,
    ) async {
      final s = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      var notifies = 0;
      s.addListener(() => notifies++);
      s.startAutoRefresh(every: every);
      now = t0.subtract(const Duration(minutes: 6));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isTrue);
      expect(notifies, 1);
      s.dispose();
    });

    testWidgets('fresh download after the clock went back is fresh', (
      tester,
    ) async {
      var online = false;
      final s = make(
        snapshotUrl: url,
        fetcher: (_) async => online
            ? snapshot(now, expiresIn: const Duration(hours: 5))
            : throw Exception('offline'),
      );
      var notifies = 0;
      s.addListener(() => notifies++);
      s.startAutoRefresh(every: every);
      now = t0.subtract(const Duration(hours: 1));
      await tester.pump(every);
      await tester.pump();
      expect(s.isStale, isTrue);
      expect(notifies, 1);
      online = true;
      await tester.pump(every);
      await tester.pump();
      expect(s.fetchedAt, now);
      expect(s.isStale, isFalse);
      expect(notifies, 2, reason: 'the download is one notify');
      s.dispose();
    });

    testWidgets('Home card: stale notice appears when clock goes back, clears '
        'when restored', (tester) async {
      await storage.saveLastPosition(inside);
      final sensors = offlineSensors();
      final service = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      service.startAutoRefresh(every: every);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
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
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);
      now = t0.subtract(const Duration(hours: 1));
      await tester.pump(every);
      await tester.pump();
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);
      now = t0.add(const Duration(minutes: 1));
      await tester.pump(every);
      await tester.pump();
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
      service.dispose();
    });
  });

  // R-F7: a cached snapshot "from the future" (phone clock behind) is stale, not fresh.
  testWidgets('cached snapshot 3 h in the future: stale, never fresh', (
    tester,
  ) async {
    final future = t0.add(const Duration(hours: 3));
    await storage.saveSnapshot(
      snapshot(future, expiresIn: const Duration(hours: 5)),
      t0,
    );
    final s = make();
    expect(s.fetchedAt, future);
    expect(s.isStale, isTrue);
    s.dispose();
  });

  // R-F9 (c): history needs proof. A tick alone (offline) never writes it; the next download
  // that no longer lists the notice records it as Expired at its own expiry time.
  testWidgets('expired while offline: history only on the next download', (
    tester,
  ) async {
    var online = false;
    final s = make(
      snapshotUrl: url,
      fetcher: (_) async => online
          ? jsonEncode({
              'generatedAt': now.toIso8601String(),
              'alerts': <Object>[],
            })
          : throw Exception('offline'),
    );
    final expiry = t0.add(const Duration(minutes: 10));
    expect(s.visibleAlerts, hasLength(1));
    s.startAutoRefresh(every: every);
    now = t0.add(const Duration(minutes: 11));
    await tester.pump(every);
    await tester.pump();
    expect(s.visibleAlerts, isEmpty);
    expect(s.history, isEmpty, reason: 'a tick alone proves nothing');
    expect(storage.alertHistory, isEmpty);
    online = true;
    now = t0.add(const Duration(minutes: 13));
    await tester.pump(every);
    await tester.pump();
    expect(s.history, hasLength(1));
    expect(s.history.single.reason, EndReason.expired);
    expect(s.history.single.endedAt, expiry);
    expect(s.history.single.record.effectiveExpiry, expiry);
    s.dispose();
  });

  group('Home', () {
    Future<void> pumpHome(
      WidgetTester tester,
      AlertService service,
      SensorService sensors,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await storage.saveLastPosition(inside);
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
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    setUpAll(() async {
      await loadAppFonts();
    });

    testWidgets('expired official Danger leaves Home while offline; stale '
        'notice appears', (tester) async {
      final sensors = offlineSensors();
      final service = make(
        snapshotUrl: url,
        fetcher: (_) async => throw Exception('offline'),
      );
      service.startAutoRefresh(every: every);
      await pumpHome(tester, service, sensors);
      expect(find.text('หัวข้อ d'), findsOneWidget);
      expect(service.levelAt(inside), AlertLevel.danger);
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);

      now = t0.add(const Duration(minutes: 11));
      await tester.pump(every);
      await tester.pump();
      expect(find.text('หัวข้อ d'), findsNothing);
      expect(service.levelAt(inside), isNot(AlertLevel.danger));
      expect(sensors.level, isNull);
      expect(find.text('ปลอดภัย'), findsNothing, reason: 'never a false Safe');

      now = t0.add(const Duration(minutes: 31));
      await tester.pump(every);
      await tester.pump();
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
      service.dispose();
    });

    // R-F7: the phone clock is 3 h behind the server's cached snapshot.
    testWidgets('cached snapshot 3 h in the future: Home shows the out-of-date '
        'notice; 30 s ahead shows none', (tester) async {
      await storage.saveSnapshot(
        snapshot(
          t0.add(const Duration(hours: 3)),
          expiresIn: const Duration(hours: 5),
        ),
        t0,
      );
      final sensors = offlineSensors();
      final service = make();
      await pumpHome(tester, service, sensors);
      expect(service.isStale, isTrue);
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dispose();

      await storage.saveSnapshot(
        snapshot(
          t0.add(const Duration(seconds: 30)),
          expiresIn: const Duration(hours: 5),
        ),
        t0,
      );
      final near = make();
      await pumpHome(tester, near, sensors);
      expect(near.isStale, isFalse);
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
      near.dispose();
    });

    // R-F10 (a): 4 min ahead is inside the alert slack (no notice); 6 min is past it.
    testWidgets('cached snapshot 4 min ahead: no out-of-date notice; 6 min '
        'ahead: notice', (tester) async {
      await storage.saveSnapshot(
        snapshot(
          t0.add(const Duration(minutes: 4)),
          expiresIn: const Duration(hours: 5),
        ),
        t0,
      );
      final sensors = offlineSensors();
      final near = make();
      await pumpHome(tester, near, sensors);
      expect(near.isStale, isFalse);
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      near.dispose();

      await storage.saveSnapshot(
        snapshot(
          t0.add(const Duration(minutes: 6)),
          expiresIn: const Duration(hours: 5),
        ),
        t0,
      );
      final far = make();
      await pumpHome(tester, far, sensors);
      expect(far.isStale, isTrue);
      expect(find.textContaining('ข้อมูลอาจไม่เป็นปัจจุบัน'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      sensors.dispose();
      far.dispose();
    });
  });
}
