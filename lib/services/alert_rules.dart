import 'package:latlong2/latlong.dart';

import '../models/alert_level.dart';
import '../models/official_alert.dart';

// Pure rules that decide which alerts a person may see (plan 7.2, 10.4).
abstract final class AlertRules {
  // Only Actual alerts, not expired, not cancelled or replaced by a later Actual message.
  static List<OfficialAlert> visible(List<OfficialAlert> all, DateTime now) {
    final dropped = <String>{
      for (final a in all)
        // A Test or Exercise message must not hide a real warning.
        if (a.status == 'Actual' &&
            (a.msgType == 'Update' || a.msgType == 'Cancel'))
          ...a.references,
    };
    return [
      for (final a in all)
        if (a.status == 'Actual' &&
            a.msgType != 'Cancel' &&
            !dropped.contains(a.id) &&
            now.isBefore(a.effectiveExpiry))
          a,
    ];
  }

  // Highest level among visible alerts whose polygon contains the point, else safe.
  static AlertLevel levelAt(
    List<OfficialAlert> alerts,
    LatLng point,
    DateTime now,
  ) {
    var best = AlertLevel.safe;
    for (final a in visible(alerts, now)) {
      if (a.polygons.any((ring) => contains(ring, point)) &&
          a.level.index > best.index) {
        best = a.level;
      }
    }
    return best;
  }

  // The level Home shows: the worse of the sensor level and an official alert at the user's
  // position. An official "no alert here" never lowers or creates a Safe; only an alert escalates.
  static AlertLevel? combine(AlertLevel? sensor, AlertLevel? official) {
    if (official == null || official == AlertLevel.safe) return sensor;
    if (sensor == null || official.index > sensor.index) return official;
    return sensor;
  }

  // Ray-casting point-in-polygon on WGS84 degrees (x = longitude, y = latitude).
  static bool contains(List<LatLng> ring, LatLng p) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) *
                      (p.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  // CAP polygons are "lat,lon lat,lon ..." text; GeoJSON is [lon, lat]. Axis order matters.
  static List<LatLng> parseCapPolygon(String text) => [
    for (final pair in text.trim().split(RegExp(r'\s+')))
      LatLng(
        double.parse(pair.split(',')[0]),
        double.parse(pair.split(',')[1]),
      ),
  ];
}
