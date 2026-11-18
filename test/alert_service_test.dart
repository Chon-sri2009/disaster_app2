import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const body =
    '{"alerts":[{"id":"a","sender":"TMD","status":"Actual","msgType":"Alert",'
    '"level":"warning","headline":{"th":"x"},"sent":"2026-11-12T01:00:00Z",'
    '"expires":"2026-11-12T05:00:00Z",'
    '"polygons":[[[100.0,13.0],[101.0,13.0],[101.0,14.0],[100.0,14.0]]]}]}';
const url = 'https://example.invalid/s.json';

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

  // The same alert with a snapshot time, as the backend's /alerts serves it.
  String withGenerated(String generatedAt) =>
      body.replaceFirst('{"alerts"', '{"generatedAt":"$generatedAt","alerts"');

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

  test('snapshot_without_generated_at_uses_download_time', () async {
    final s = service(text: () => body);
    await s.refresh();
    expect(s.fetchedAt, now);
    expect(s.isStale, isFalse);
  });

  test('future_generated_at_is_clamped_to_now', () async {
    final s = service(
      text: () => withGenerated(
        now.add(const Duration(hours: 3)).toIso8601String(),
      ),
    );
    await s.refresh();
    expect(s.fetchedAt, now);
    // Clock skew must not keep the data fresh once real time passes.
    now = now.add(const Duration(minutes: 31));
    expect(s.isStale, isTrue);
  });

  test('invalid_generated_at_falls_back_to_download_time', () async {
    final s = service(text: () => withGenerated('not a time'));
    await s.refresh();
    expect(s.hasSnapshot, isTrue);
    expect(s.fetchedAt, now);
    expect(s.visibleAlerts, hasLength(1));
  });

  test('cached_old_snapshot_is_stale_on_next_launch', () async {
    final generated = now.subtract(const Duration(hours: 2));
    await service(
      text: () => withGenerated(generated.toIso8601String()),
    ).refresh();
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
