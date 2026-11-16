// An evacuation shelter with a map position; can be saved to and loaded from JSON for the offline cache.
class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.capacity,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final int capacity;

  // Builds a shelter from a decoded JSON map.
  factory Shelter.fromJson(Map<String, dynamic> json) => Shelter(
    id: json['id'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    capacity: json['capacity'] as int,
  );

  // Converts the shelter to a JSON-friendly map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'capacity': capacity,
  };
}
