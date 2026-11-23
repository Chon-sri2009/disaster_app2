import 'dart:async';

import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:flutter_test/flutter_test.dart';

const url = 'https://example.invalid/snapshot';

String snapWith(String generatedAt) =>
    '{"generatedAt":$generatedAt,"stations":[${st('a', 'safe')}]}';
String st(String id, String band, [String status = 'ok']) =>
    '{"id":"$id","name":"$id","band":"$band","status":"$status","waterCm":100,'
    '"readingTime":"2026-11-16T01:00:00Z"}';

void main() {
  var now = DateTime.utc(2026, 11, 16, 1);

  // The server's build time follows the injected clock at fetch time (age comes from it).
  String snap(List<String> stations, {String? generatedAt}) =>
      '{"generatedAt":"${generatedAt ?? now.toIso8601String()}",'
      '"stations":[${stations.join(',')}]}';

  SensorService make(Future<String> Function(Uri) fetch) =>
      SensorService(snapshotUrl: url, fetcher: fetch, clock: () => now);

  setUp(() => now = DateTime.utc(2026, 11, 16, 1));

  test('no data yet: level is null, never Safe', () async {
    final s = make((_) async => throw Exception('offline'));
    await s.refresh();
    expect(s.level, isNull);
    s.dispose();
  });

  test('worst usable station wins; unusable stations are ignored', () async {
    final s = make(
      (_) async => snap([
        st('a', 'safe'),
        st('b', 'danger'),
        st('c', 'danger', 'stale'),
      ]),
    );
    await s.refresh();
    expect(s.level, AlertLevel.danger);
    s.dispose();
  });

  test('a station with status not ok is no data, not Safe', () async {
    final s = make((_) async => snap([st('a', 'safe', 'offline')]));
    await s.refresh();
    expect(s.level, isNull);
    s.dispose();
  });

  test('stale Safe becomes no data; stale Watch is kept', () async {
    var body = snap([st('a', 'safe')]);
    final s = make((_) async => body);
    await s.refresh();
    expect(s.level, AlertLevel.safe);
    now = now.add(const Duration(minutes: 6));
    expect(s.level, isNull);
    now = DateTime.utc(2026, 11, 16, 1);
    body = snap([st('a', 'watch')]);
    await s.refresh();
    now = now.add(const Duration(minutes: 6));
    expect(s.level, AlertLevel.watch);
    s.dispose();
  });

  test('a failed refresh keeps the last good data', () async {
    var fail = false;
    final s = make((_) async {
      if (fail) throw Exception('offline');
      return snap([st('a', 'watch')]);
    });
    await s.refresh();
    fail = true;
    await s.refresh();
    expect(s.level, AlertLevel.watch);
    s.dispose();
  });

  test('bad JSON is ignored', () async {
    final s = make((_) async => 'not json');
    await s.refresh();
    expect(s.level, isNull);
    s.dispose();
  });

  // R-F8: age comes from the server's generatedAt, not from the download time.
  group('generatedAt (R-F8)', () {
    final stations = [st('a', 'safe')];
    String at(Duration d) => now.add(d).toIso8601String();

    test('2 h old data from a fresh download is stale, Safe is null', () async {
      final s = make(
        (_) async => snap(
          stations,
          generatedAt: at(const Duration(hours: -2)),
        ),
      );
      await s.refresh();
      expect(s.isStale, isTrue);
      expect(s.level, isNull);
      expect(s.fetchedAt, now.subtract(const Duration(hours: 2)));
      s.dispose();
    });

    test('fresh generatedAt is Safe', () async {
      final s = make((_) async => snap(stations));
      await s.refresh();
      expect(s.isStale, isFalse);
      expect(s.level, AlertLevel.safe);
      expect(s.fetchedAt, now);
      s.dispose();
    });

    test('backend format (+00:00 with microseconds) is accepted', () async {
      final s = make(
        (_) async =>
            snap(stations, generatedAt: '2026-11-16T01:00:00.123456+00:00'),
      );
      await s.refresh();
      expect(s.level, AlertLevel.safe);
      expect(s.fetchedAt, DateTime.utc(2026, 11, 16, 1, 0, 0, 123, 456));
      s.dispose();
    });

    test('stale Danger and stale Watch stay as they are', () async {
      for (final (band, level) in [
        ('danger', AlertLevel.danger),
        ('watch', AlertLevel.watch),
      ]) {
        final s = make(
          (_) async => snap(
            [st('a', band)],
            generatedAt: at(const Duration(hours: -2)),
          ),
        );
        await s.refresh();
        expect(s.isStale, isTrue, reason: band);
        expect(s.level, level, reason: band);
        s.dispose();
      }
    });

    test('30 s in the future is fresh; 2 min in the future is stale', () async {
      var gen = const Duration(seconds: 30);
      final s = make(
        (_) async => snap(stations, generatedAt: at(gen)),
      );
      await s.refresh();
      expect(s.isStale, isFalse);
      expect(s.level, AlertLevel.safe);
      gen = const Duration(minutes: 2);
      await s.refresh();
      expect(s.isStale, isTrue);
      expect(s.level, isNull);
      s.dispose();
    });

    // A body with no usable generatedAt is rejected whole.
    final bad = <String, String>{
      'missing': '{"stations":[${st('a', 'safe')}]}',
      'garbage': snapWith('"garbage"'),
      'no zone': snapWith('"2026-11-16T01:00:00"'),
      'a number': snapWith('1763254800'),
      'null': snapWith('null'),
    };
    for (final e in bad.entries) {
      test('${e.key} generatedAt: first fetch gives no level, no time', () async {
        final s = make((_) async => e.value);
        await s.refresh();
        expect(s.level, isNull);
        expect(s.fetchedAt, isNull);
        expect(s.stations, isEmpty);
        s.dispose();
      });

      test('${e.key} generatedAt: last good data is untouched', () async {
        var body = snap(stations);
        final s = make((_) async => body);
        await s.refresh();
        final good = s.stations;
        final goodAt = s.fetchedAt;
        expect(goodAt, isNotNull);
        body = e.value.replaceAll('"safe"', '"danger"');
        await s.refresh();
        expect(s.stations, same(good));
        expect(s.fetchedAt, goodAt);
        expect(s.level, AlertLevel.safe);
        s.dispose();
      });
    }
  });

  // R-F5: httpGetText's deadline throws TimeoutException; that must release _busy so the
  // next tick refreshes instead of the service staying frozen on old data.
  testWidgets('timeout_releases_busy_and_next_tick_refreshes', (tester) async {
    var calls = 0;
    final s = make((_) {
      calls++;
      if (calls == 1) return Future.error(TimeoutException('deadline'));
      return Future.value(snap([st('a', 'watch')]));
    });
    await tester.pump(); // first refresh (from the constructor) fails
    expect(calls, 1);
    expect(s.level, isNull);
    await tester.pump(SensorService.pollEvery);
    await tester.pump();
    expect(calls, 2);
    expect(s.level, AlertLevel.watch);
    s.dispose();
  });

  testWidgets('hung_fetch_skips_ticks_then_recovers_after_it_fails', (tester) async {
    var calls = 0;
    final hang = Completer<String>();
    final s = make((_) {
      calls++;
      if (calls == 1) return hang.future;
      return Future.value(snap([st('a', 'watch')]));
    });
    await tester.pump(SensorService.pollEvery);
    expect(calls, 1); // busy: tick skipped
    hang.completeError(TimeoutException('deadline'));
    await tester.pump();
    await tester.pump(SensorService.pollEvery);
    await tester.pump();
    expect(calls, 2);
    expect(s.level, AlertLevel.watch);
    s.dispose();
  });
}
