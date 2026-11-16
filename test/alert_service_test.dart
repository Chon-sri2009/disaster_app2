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
