import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import 'alert_rules.dart';

// One province from assets/boundaries/th_provinces.json (COD-AB, CC BY-IGO).
class Province {
  const Province({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.rings,
  });

  final String code; // ISO 3166-2, e.g. "TH-10"
  final String nameTh;
  final String nameEn;
  final List<List<LatLng>> rings; // holes are plain extra rings (even-odd)
}

// Finds the province a point is in, on the phone (coordinates never leave it).
// Borders are simplified to ~330 m, so within ~300 m of a border the answer may be the
// neighbour or null. Null always means "unknown", never "no alert here".
class ProvinceBoundaries {
  ProvinceBoundaries._(this.provinces)
    : _boxes = [for (final p in provinces) _Box.of(p.rings)];

  static const assetPath = 'assets/boundaries/th_provinces.json';

  // Used when the bundle cannot be read: every query answers null.
  static final empty = ProvinceBoundaries._(const []);

  final List<Province> provinces;
  final List<_Box> _boxes;

  // Pure parse of the asset's JSON ([lon, lat] rings). Throws on bad input; load() catches.
  factory ProvinceBoundaries.parse(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ProvinceBoundaries._([
      for (final p in map['provinces'] as List)
        Province(
          code: (p as Map<String, dynamic>)['code'] as String,
          nameTh: p['nameTh'] as String,
          nameEn: p['nameEn'] as String,
          rings: [
            for (final ring in p['rings'] as List)
              [
                for (final pt in ring as List)
                  LatLng(
                    ((pt as List)[1] as num).toDouble(),
                    (pt[0] as num).toDouble(),
                  ),
              ],
          ],
        ),
    ]);
  }

  // Reads the bundled asset. Never throws into the UI: any failure gives [empty].
  static Future<ProvinceBoundaries> load({
    Future<String> Function()? read,
  }) async {
    try {
      final text = await (read ?? () => rootBundle.loadString(assetPath))();
      return ProvinceBoundaries.parse(text);
    } catch (_) {
      return empty;
    }
  }

  // The province containing [point], or null. The bbox check skips most of the ~26k
  // vertices. If simplified borders overlap, the first province in file order wins: a
  // fixed choice, not an authoritative one.
  String? codeAt(LatLng point) {
    for (var i = 0; i < provinces.length; i++) {
      if (!_boxes[i].has(point)) continue;
      // Even-odd over all rings: inside an odd number of rings is inside (a hole is out).
      var count = 0;
      for (final ring in provinces[i].rings) {
        if (AlertRules.contains(ring, point)) count++;
      }
      if (count.isOdd) return provinces[i].code;
    }
    return null;
  }

  Province? byCode(String code) {
    for (final p in provinces) {
      if (p.code == code) return p;
    }
    return null;
  }
}

class _Box {
  const _Box(this.south, this.west, this.north, this.east);

  factory _Box.of(List<List<LatLng>> rings) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final ring in rings) {
      for (final p in ring) {
        if (p.latitude < s) s = p.latitude;
        if (p.latitude > n) n = p.latitude;
        if (p.longitude < w) w = p.longitude;
        if (p.longitude > e) e = p.longitude;
      }
    }
    return _Box(s, w, n, e);
  }

  final double south, west, north, east;

  bool has(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;
}
