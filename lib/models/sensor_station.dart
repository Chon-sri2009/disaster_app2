// A physical sensor station (future ESP32 node) shown as a marker on the map.
class SensorStation {
  const SensorStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
}
