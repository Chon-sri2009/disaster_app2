import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../models/flood_history.dart';
import 'http_get.dart';

// Asks our backend for GISTDA flood history at a position. The GISTDA key stays on the server.
// The position leaves the phone only for this call, and only when a backend address is
// configured. Any failure returns null so the card simply stays hidden.
class FloodHistoryService {
  FloodHistoryService({
    this.snapshotUrl = '',
    Future<String> Function(Uri url)? fetcher,
  }) : _fetch = fetcher ?? httpGetText;

  // Same host as the sensor snapshot (--dart-define=SENSOR_SNAPSHOT_URL).
  final String snapshotUrl;
  final Future<String> Function(Uri url) _fetch;

  bool get isLive => Uri.tryParse(snapshotUrl)?.scheme == 'https';

  Future<FloodHistory?> at(LatLng point) async {
    if (!isLive) return null;
    try {
      final url = Uri.parse(snapshotUrl).replace(
        path: '/flood-recurrence',
        queryParameters: {
          'lat': '${point.latitude}',
          'lng': '${point.longitude}',
        },
      );
      final json = jsonDecode(await _fetch(url)) as Map<String, dynamic>;
      return FloodHistory.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
