import 'package:latlong2/latlong.dart';

import '../models/shelter.dart';

// Straight-line distances to shelters from a known position.
abstract final class Nearby {
  static double metersTo(LatLng from, Shelter s) =>
      const Distance()(from, LatLng(s.lat, s.lng));

  // Nearest first when a position is known, otherwise the saved order.
  static List<Shelter> sorted(List<Shelter> shelters, LatLng? from) {
    if (from == null) return shelters;
    return [...shelters]
      ..sort((a, b) => metersTo(from, a).compareTo(metersTo(from, b)));
  }
}
