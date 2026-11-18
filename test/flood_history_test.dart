import 'package:disaster_app2/services/flood_history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _url = 'https://example.invalid/snapshot';
const _body =
    '{"found":true,"source":"GISTDA","district":"B","province":"C","years":'
    '[{"year":2011,"freq":2},{"year":2012,"freq":0}]}';

void main() {
  test('parses a record and asks the backend for the point', () async {
    Uri? asked;
    final s = FloodHistoryService(
      snapshotUrl: _url,
      fetcher: (u) async {
        asked = u;
        return _body;
      },
    );
    final h = await s.at(const LatLng(14.35, 100.57));
    expect(asked!.path, '/flood-recurrence');
    expect(asked!.queryParameters, {'lat': '14.35', 'lng': '100.57'});
    expect(h!.found, isTrue);
    expect(h.floodedYears, 1);
    expect(h.province, 'C');
  });

  test('no record is found=false, not an error', () async {
    final s = FloodHistoryService(
      snapshotUrl: _url,
      fetcher: (_) async => '{"found":false,"source":"GISTDA"}',
    );
    final h = await s.at(const LatLng(1, 2));
    expect(h!.found, isFalse);
  });

  test('offline, bad data or no backend gives null', () async {
    final failing = FloodHistoryService(
      snapshotUrl: _url,
      fetcher: (_) async => throw Exception('offline'),
    );
    expect(await failing.at(const LatLng(1, 2)), isNull);
    final junk = FloodHistoryService(
      snapshotUrl: _url,
      fetcher: (_) async => '[]',
    );
    expect(await junk.at(const LatLng(1, 2)), isNull);
    expect(await FloodHistoryService().at(const LatLng(1, 2)), isNull);
  });
}
