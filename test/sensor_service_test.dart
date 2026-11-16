import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:flutter_test/flutter_test.dart';

const url = 'https://example.invalid/snapshot';

String snap(List<String> stations) => '{"stations":[${stations.join(',')}]}';
String st(String id, String band, [String status = 'ok']) =>
    '{"id":"$id","name":"$id","band":"$band","status":"$status","waterCm":100,'
    '"readingTime":"2026-11-16T01:00:00Z"}';

void main() {
  var now = DateTime.utc(2026, 11, 16, 1);

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
}
