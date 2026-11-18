import 'package:latlong2/latlong.dart';

import '../models/alert_level.dart';
import '../models/official_alert.dart';

// Declared order is the sort order on Home: yours first, unknown next, other areas last.
enum AlertArea { inYourArea, unknown, otherAreas }

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

  // Highest level among visible alerts that match the point, else safe.
  static AlertLevel levelAt(
    List<OfficialAlert> alerts,
    LatLng point,
    DateTime now, {
    String? provinceCode,
  }) {
    var best = AlertLevel.safe;
    for (final a in visible(alerts, now)) {
      if (matches(a, point, provinceCode) && a.level.index > best.index) {
        best = a.level;
      }
    }
    return best;
  }

  // Does the alert apply to this person? Polygons are finer than provinces, so when an alert
  // has them they decide alone (provisional rule: real TMD polygons cover >= 88% of every
  // province they list, docs/CAP_FIELDS.md). Province codes count only for alerts without
  // polygons, and only when the user's province is known.
  static bool matches(OfficialAlert a, LatLng point, String? provinceCode) {
    if (a.polygons.isNotEmpty) {
      return a.polygons.any((ring) => contains(ring, point));
    }
    return provinceCode != null && a.areaCodes.contains(provinceCode);
  }

  // The area tag of a notice, decided by [matches] so the tag and the level cannot disagree.
  // "Other areas" is said only when we can tell: a polygon always can; a province code list
  // cannot be judged without the user's province. Then the honest answer is unknown.
  static AlertArea areaOf(
    OfficialAlert a,
    LatLng? point,
    String? provinceCode,
  ) {
    if (point == null) return AlertArea.unknown;
    if (matches(a, point, provinceCode)) return AlertArea.inYourArea;
    if (a.polygons.isNotEmpty || provinceCode != null) {
      return AlertArea.otherAreas;
    }
    return AlertArea.unknown;
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
