import 'dart:io';

import 'package:disaster_app2/services/alert_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// test/fixtures/alerts_snapshot.json is built by the backend (backend/test_tmd_poller.py,
// ContractTest) at a fixed clock. If the backend changes the shape, regenerate it there; this
// test then proves the app still reads what the backend really emits.
void main() {
  test('the app reads the backend snapshot contract file', () async {
    final text = File('test/fixtures/alerts_snapshot.json').readAsStringSync();
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final clock = DateTime.utc(2026, 11, 18, 10, 50);
    final s = AlertService(
      storage,
      snapshotUrl: 'https://example.invalid/alerts',
      fetcher: (_) async => text,
      clock: () => clock,
    );
    await s.refresh();

    expect(s.hasSnapshot, isTrue);
    expect(s.fetchedAt, clock);
    expect(s.skippedFiles, 0);
    expect(s.isStale, isFalse);

    final visible = s.visibleAlerts;
    final ids = visible.map((a) => a.id).toSet();
    expect(visible, isNotEmpty);
    expect(ids, containsAll(['SYN_ALERT', 'SYN_NOEXP', 'SYN_NOHEAD']));
    // An empty headline is a valid backend output and must read without throwing.
    expect(visible.firstWhere((a) => a.id == 'SYN_NOHEAD').headline, isEmpty);
    // An Actual Cancel hides its target; an Actual Update replaces its alert.
    expect(ids, isNot(contains('SYN_TARGET')));
    expect(ids, isNot(contains('SYN_OLD')));
    expect(ids, contains('SYN_UPDATE'));
    // A Test-status Cancel must not hide a live alert.
    expect(ids, contains('SYN_LIVE'));
    expect(ids, isNot(contains('SYN_TESTCANCEL')));
  });
}
