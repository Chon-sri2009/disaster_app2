import 'dart:async';
import 'dart:convert';

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
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R-F3: time passing, or a failed poll, can make a Safe snapshot stale (hard rule 1: never a
// false Safe). The service must tell its listeners once when it flips, on its own poll tick.
// testWidgets runs timers on fake time, so tester.pump(duration) fires the periodic timer; the
// injected clock is separate, so each test moves it by hand too.

const _url = 'https://example.invalid/snapshot';
final _t0 = DateTime.utc(2026, 11, 22, 3);
const _tick = Duration(seconds: 31);

// generatedAt is the server's build time; tests pass the injected clock's reading at fetch time.
String _snap(String band, DateTime generatedAt) => jsonEncode({
  'generatedAt': generatedAt.toIso8601String(),
  'stations': [
    {
      'id': 'a',
      'name': 'Station A',
      'band': band,
      'status': 'ok',
      'waterCm': 100,
      'readingTime': _t0.toIso8601String(),
    },
  ],
});

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testWidgets('offline after Safe: one notify when the data ages out, level null', (
    tester,
  ) async {
    var now = _t0;
    var offline = false;
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async =>
          offline ? throw StateError('offline') : _snap('safe', now),
      clock: () => now,
    );
    await tester.pump(); // the constructor's first refresh lands
    expect(s.level, AlertLevel.safe);
    var notifies = 0;
    s.addListener(() => notifies++);
    offline = true;
    now = _t0.add(const Duration(minutes: 6));
    await tester.pump(_tick);
    expect(s.level, isNull);
    expect(notifies, 1);
    await tester.pump(_tick);
    expect(notifies, 1);
    s.dispose();
  });

  testWidgets('fresh Safe stays Safe and the tick does not notify', (
    tester,
  ) async {
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async => _snap('safe', _t0),
      clock: () => _t0,
    );
    await tester.pump();
    var notifies = 0;
    s.addListener(() => notifies++);
    await tester.pump(_tick);
    expect(s.level, AlertLevel.safe);
    // The tick's own refresh succeeds and notifies once with fresh data; the stale check adds none.
    final afterFirst = notifies;
    await tester.pump(_tick);
    expect(s.level, AlertLevel.safe);
    expect(notifies - afterFirst, 1); // one per successful poll, no extra
    s.dispose();
  });

  testWidgets('failed poll then recovery: one notify each way', (tester) async {
    var now = _t0;
    var offline = false;
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async =>
          offline ? throw StateError('offline') : _snap('safe', now),
      clock: () => now,
    );
    await tester.pump();
    var notifies = 0;
    s.addListener(() => notifies++);
    offline = true;
    now = _t0.add(const Duration(minutes: 6));
    await tester.pump(_tick);
    expect(s.level, isNull);
    expect(notifies, 1);
    offline = false;
    await tester.pump(_tick);
    expect(s.level, AlertLevel.safe);
    expect(notifies, 2, reason: 'recovery is one notify, not two');
    s.dispose();
  });

  testWidgets('a hung fetch still lets the data age out, once', (tester) async {
    var now = _t0;
    var calls = 0;
    final hang = Completer<String>();
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) {
        calls++;
        return calls == 1 ? Future.value(_snap('safe', now)) : hang.future;
      },
      clock: () => now,
    );
    await tester.pump();
    var notifies = 0;
    s.addListener(() => notifies++);
    now = _t0.add(const Duration(minutes: 6));
    await tester.pump(_tick);
    expect(s.level, isNull);
    expect(notifies, 1);
    await tester.pump(_tick);
    expect(notifies, 1);
    s.dispose();
  });

  testWidgets('stale Danger stays Danger (worse news is never hidden)', (
    tester,
  ) async {
    var now = _t0;
    var offline = false;
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async =>
          offline ? throw StateError('offline') : _snap('danger', now),
      clock: () => now,
    );
    await tester.pump();
    offline = true;
    now = _t0.add(const Duration(minutes: 6));
    await tester.pump(_tick);
    expect(s.isStale, isTrue);
    expect(s.level, AlertLevel.danger);
    s.dispose();
  });

  // R-F6: a phone clock that moves BACK after a download gives a negative age; that must not
  // keep an old Safe alive. Beyond the 1 min slack it counts as stale.
  group('clock moved backwards (R-F6)', () {
    Future<(SensorService, void Function(bool), void Function(DateTime), int Function())>
    make(WidgetTester tester) async {
      var now = _t0;
      var offline = false;
      final s = SensorService(
        snapshotUrl: _url,
        fetcher: (_) async =>
            offline ? throw StateError('offline') : _snap('safe', now),
        clock: () => now,
      );
      await tester.pump();
      expect(s.level, AlertLevel.safe);
      var notifies = 0;
      s.addListener(() => notifies++);
      return (
        s,
        (bool v) => offline = v,
        (DateTime t) => now = t,
        () => notifies,
      );
    }

    testWidgets('1 h back: level null, exactly one notify', (tester) async {
      final (s, setOffline, setNow, notifies) = await make(tester);
      setOffline(true);
      setNow(_t0.subtract(const Duration(hours: 1)));
      await tester.pump(_tick);
      expect(s.isStale, isTrue);
      expect(s.level, isNull);
      expect(notifies(), 1);
      await tester.pump(_tick);
      expect(notifies(), 1);
      s.dispose();
    });

    testWidgets('30 s back (within slack): still Safe, no notify', (
      tester,
    ) async {
      final (s, setOffline, setNow, notifies) = await make(tester);
      setOffline(true);
      setNow(_t0.subtract(const Duration(seconds: 30)));
      await tester.pump(_tick);
      expect(s.isStale, isFalse);
      expect(s.level, AlertLevel.safe);
      expect(notifies(), 0);
      s.dispose();
    });

    testWidgets('clock restored forward: not stale, one notify', (
      tester,
    ) async {
      final (s, setOffline, setNow, notifies) = await make(tester);
      setOffline(true);
      setNow(_t0.subtract(const Duration(hours: 1)));
      await tester.pump(_tick);
      expect(s.level, isNull);
      expect(notifies(), 1);
      setNow(_t0.add(const Duration(minutes: 1)));
      await tester.pump(_tick);
      expect(s.isStale, isFalse);
      expect(s.level, AlertLevel.safe);
      expect(notifies(), 2);
      s.dispose();
    });

    testWidgets('fresh download after the clock went back is fresh Safe', (
      tester,
    ) async {
      final (s, setOffline, setNow, notifies) = await make(tester);
      setOffline(true);
      setNow(_t0.subtract(const Duration(hours: 1)));
      await tester.pump(_tick);
      expect(s.level, isNull);
      expect(notifies(), 1);
      setOffline(false);
      await tester.pump(_tick);
      expect(s.fetchedAt, _t0.subtract(const Duration(hours: 1)));
      expect(s.isStale, isFalse);
      expect(s.level, AlertLevel.safe);
      expect(notifies(), 2, reason: 'the download is one notify');
      s.dispose();
    });
  });

  // R-F8: the phone clock is 1 h behind the server. The server's time is in the future for
  // the phone, so the data is stale even though it was just downloaded: never a false Safe.
  testWidgets('server time ahead of a phone clock 1 h back is stale, not Safe', (
    tester,
  ) async {
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async => _snap('safe', _t0),
      clock: () => _t0.subtract(const Duration(hours: 1)),
    );
    await tester.pump();
    expect(s.isStale, isTrue);
    expect(s.level, isNull);
    s.dispose();
  });

  // R-F9 (a): a fetch that finishes after dispose must not notify or write state.
  testWidgets('fetch completing after dispose does not notify', (tester) async {
    final gate = Completer<String>();
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) => gate.future,
      clock: () => _t0,
    );
    var notifies = 0;
    s.addListener(() => notifies++);
    s.dispose();
    gate.complete(_snap('safe', _t0));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(notifies, 0);
    expect(s.stations, isEmpty);
    expect(s.fetchedAt, isNull);
  });

  testWidgets('fetch failing after dispose does not notify', (tester) async {
    // A good first download, then a poll that is still running when the data goes stale
    // and the service is disposed: its late failure would flip staleness, but must be quiet.
    var now = _t0;
    var calls = 0;
    final gate = Completer<String>();
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) {
        calls++;
        return calls == 1 ? Future.value(_snap('safe', _t0)) : gate.future;
      },
      clock: () => now,
    );
    await tester.pump();
    var notifies = 0;
    s.addListener(() => notifies++);
    now = _t0.add(const Duration(seconds: 1));
    await tester.pump(_tick); // second refresh starts and hangs
    expect(calls, 2);
    now = _t0.add(const Duration(minutes: 6));
    s.dispose();
    gate.completeError(StateError('offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(notifies, 0);
  });

  // R-F9 (c): the first tick when the constructor's fetch failed has nothing to flip.
  testWidgets('first tick after a failed first fetch: no notify, level null', (
    tester,
  ) async {
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async => throw StateError('offline'),
      clock: () => _t0,
    );
    await tester.pump(); // the constructor's first refresh fails
    var notifies = 0;
    s.addListener(() => notifies++);
    await tester.pump(_tick);
    expect(s.level, isNull);
    expect(notifies, 0);
    s.dispose();
  });

  // R-F9 (c): the stale test is strict: exactly 5:00 old is fresh, 1 ms more is stale.
  testWidgets('exact 5:00 boundary: not stale; 5:00.001 stale', (tester) async {
    var now = _t0;
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async => _snap('safe', _t0),
      clock: () => now,
    );
    await tester.pump();
    now = _t0.add(SensorService.staleAfter);
    expect(s.isStale, isFalse);
    expect(s.level, AlertLevel.safe);
    now = _t0.add(SensorService.staleAfter + const Duration(milliseconds: 1));
    expect(s.isStale, isTrue);
    expect(s.level, isNull);
    s.dispose();
  });

  group('Home level slab', () {
    Future<void> Function() cleanup = () async {};

    Future<SensorService> pumpHome(
      WidgetTester tester,
      String band,
      DateTime Function() clock,
      bool Function() offline,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final sensors = SensorService(
        snapshotUrl: _url,
        fetcher: (_) async =>
            offline() ? throw StateError('offline') : _snap(band, clock()),
        clock: clock,
      );
      final alerts = AlertService(storage);
      cleanup = () async {
        await tester.pumpWidget(const SizedBox());
        sensors.dispose();
        alerts.dispose();
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('th'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      return sensors;
    }

    testWidgets('Safe, then offline: the slab says No live data, no Safe word', (
      tester,
    ) async {
      var now = _t0;
      var offline = false;
      await pumpHome(tester, 'safe', () => now, () => offline);
      expect(find.text('Safe'), findsWidgets);
      expect(find.text('No live data'), findsNothing);
      offline = true;
      now = _t0.add(const Duration(minutes: 6));
      await tester.pump(_tick);
      expect(find.text('No live data'), findsWidgets);
      expect(find.text('Safe'), findsNothing);
      await cleanup();
    });

    testWidgets('stale Danger: slab keeps Danger and shows may be out of date', (
      tester,
    ) async {
      var now = _t0;
      var offline = false;
      await pumpHome(tester, 'danger', () => now, () => offline);
      expect(find.textContaining('may be out of date'), findsNothing);
      offline = true;
      now = _t0.add(const Duration(minutes: 6));
      await tester.pump(_tick);
      expect(find.textContaining('may be out of date'), findsOneWidget);
      expect(find.text('Danger'), findsWidgets);
      expect(find.text('No live data'), findsNothing);
      await cleanup();
    });
  });
}
