import 'dart:async';

import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The alert as the backend serves it, without the snapshot time.
const bodyNoGen =
    '{"alerts":[{"id":"a","sender":"TMD","status":"Actual","msgType":"Alert",'
    '"level":"warning","headline":{"th":"x"},"sent":"2026-11-12T01:00:00Z",'
    '"expires":"2026-11-12T05:00:00Z",'
    '"polygons":[[[100.0,13.0],[101.0,13.0],[101.0,14.0],[100.0,14.0]]]}]}';
const url = 'https://example.invalid/s.json';

// The same alert with a snapshot time, as the backend's /alerts serves it.
String withGenerated(String generatedAt, [String raw = bodyNoGen]) =>
    raw.replaceFirst('{"alerts"', '{"generatedAt":"$generatedAt","alerts"');

// Generated 5 minutes before the tests' fixed clock (2026-11-12T02:00Z).
final body = withGenerated('2026-11-12T01:55:00Z');

void main() {
  late StorageService storage;
  var now = DateTime.utc(2026, 11, 12, 2);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    now = DateTime.utc(2026, 11, 12, 2);
  });

  test('refresh stores snapshot; a new service reads it offline', () async {
    final s = AlertService(
      storage,
      snapshotUrl: url,
      fetcher: (_) async => body,
      clock: () => now,
    );
    await s.refresh();
    expect(s.levelAt(LatLng(13.5, 100.5)), AlertLevel.warning);
    final offline = AlertService(
      storage,
      snapshotUrl: url,
      fetcher: (_) async => throw Exception('offline'),
      clock: () => now,
    );
    await offline.refresh();
    expect(offline.visibleAlerts, hasLength(1));
  });

  test('stale after 30 minutes, expired alerts vanish', () async {
    final s = AlertService(
      storage,
      snapshotUrl: url,
      fetcher: (_) async => body,
      clock: () => now,
    );
    await s.refresh();
    expect(s.isStale, isFalse);
    now = now.add(const Duration(minutes: 31));
    expect(s.isStale, isTrue);
    now = DateTime.utc(2026, 11, 12, 5, 1);
    expect(s.visibleAlerts, isEmpty);
  });

  AlertService service({String Function()? text, Object? error}) =>
      AlertService(
        storage,
        snapshotUrl: url,
        fetcher: (_) async => error != null ? throw error : text!(),
        clock: () => now,
      );

  test(
    'stale_when_snapshot_generated_long_ago_even_if_just_downloaded',
    () async {
      final generated = now.subtract(const Duration(hours: 2));
      final s = service(text: () => withGenerated(generated.toIso8601String()));
      await s.refresh();
      expect(s.hasSnapshot, isTrue);
      expect(s.isStale, isTrue);
      expect(s.fetchedAt, generated);
    },
  );

  test('fresh_when_generated_recently', () async {
    final generated = now.subtract(const Duration(minutes: 5));
    final s = service(text: () => withGenerated(generated.toIso8601String()));
    await s.refresh();
    expect(s.isStale, isFalse);
    expect(s.fetchedAt, generated);
  });

  test('live_refresh_without_generated_at_keeps_previous_state', () async {
    final good = service(text: () => body);
    await good.refresh();
    final saved = storage.snapshot!.json;
    final bad = service(text: () => bodyNoGen);
    await bad.refresh();
    expect(bad.fetchedAt, DateTime.utc(2026, 11, 12, 1, 55));
    expect(storage.snapshot!.json, saved);
  });

  test('live_refresh_without_generated_at_is_not_fresh_data', () async {
    final s = service(text: () => bodyNoGen);
    await s.refresh();
    expect(s.hasSnapshot, isFalse);
    expect(storage.snapshot, isNull);
  });

  test(
    'cached_old_body_without_generated_at_loads_with_download_time',
    () async {
      await storage.saveSnapshot(bodyNoGen, now);
      final s = service(error: Exception('offline'));
      expect(s.hasSnapshot, isTrue);
      expect(s.fetchedAt, now);
      expect(s.visibleAlerts, hasLength(1));
    },
  );

  test('offset_generated_at_converts_to_the_right_utc_instant', () async {
    final s = service(text: () => withGenerated('2026-11-12T08:50:00+07:00'));
    await s.refresh();
    expect(s.fetchedAt, DateTime.utc(2026, 11, 12, 1, 50));
  });

  test('skipped_files_makes_fresh_snapshot_stale', () async {
    final s = service(
      text: () => body.replaceFirst(
        '{"generatedAt"',
        '{"skippedFiles":2,"generatedAt"',
      ),
    );
    await s.refresh();
    expect(s.hasSnapshot, isTrue);
    expect(s.skippedFiles, 2);
    expect(s.isStale, isTrue);
    expect(s.visibleAlerts, hasLength(1));
  });

  test('missing_or_invalid_skipped_files_is_zero', () async {
    final a = service(text: () => body);
    await a.refresh();
    expect(a.skippedFiles, 0);
    expect(a.isStale, isFalse);
    final b = service(
      text: () => body.replaceFirst(
        '{"generatedAt"',
        '{"skippedFiles":"x","generatedAt"',
      ),
    );
    await b.refresh();
    expect(b.skippedFiles, 0);
    expect(b.isStale, isFalse);
  });

  // testWidgets runs timers on fake time, so tester.pump(duration) fires them.
  testWidgets('auto_refresh_ticks_skip_while_busy_and_dispose_cancels', (
    tester,
  ) async {
    var calls = 0;
    final gate = Completer<String>();
    final s = AlertService(
      storage,
      snapshotUrl: url,
      fetcher: (_) {
        calls++;
        return gate.future;
      },
      clock: () => now,
    );
    s.startAutoRefresh(every: const Duration(minutes: 2));
    s.startAutoRefresh(every: const Duration(minutes: 2)); // no second timer
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 1);
    await tester.pump(
      const Duration(minutes: 4),
    ); // first still running: skipped
    expect(calls, 1);
    gate.complete(body);
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 2);
    s.dispose();
    await tester.pump(const Duration(minutes: 10));
    expect(calls, 2);
  });

  test('future_generated_at_is_clamped_to_now', () async {
    final s = service(
      text: () =>
          withGenerated(now.add(const Duration(hours: 3)).toIso8601String()),
    );
    await s.refresh();
    expect(s.fetchedAt, now);
    // Clock skew must not keep the data fresh once real time passes.
    now = now.add(const Duration(minutes: 31));
    expect(s.isStale, isTrue);
  });

  test('invalid_generated_at_is_rejected_on_live_refresh', () async {
    final s = service(text: () => withGenerated('not a time'));
    await s.refresh();
    expect(s.hasSnapshot, isFalse);
    expect(storage.snapshot, isNull);
  });

  test('cached_old_snapshot_is_stale_on_next_launch', () async {
    final generated = now.subtract(const Duration(hours: 2));
    await service(text: () => withGenerated(generated.toIso8601String()))
        .refresh();
    final next = service(error: Exception('offline'));
    await next.refresh();
    expect(next.hasSnapshot, isTrue);
    expect(next.fetchedAt, generated);
    expect(next.isStale, isTrue);
  });

  test('empty or non-https URL fetches nothing', () async {
    final s = AlertService(
      storage,
      snapshotUrl: 'http://example.invalid/s.json',
      fetcher: (_) async => throw StateError('must not be called'),
    );
    await s.refresh();
    expect(s.hasSnapshot, isFalse);
  });
}
