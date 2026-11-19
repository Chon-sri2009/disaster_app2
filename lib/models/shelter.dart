// An evacuation shelter with a map position; can be saved to and loaded from JSON for the offline cache.
class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    this.nameTh,
    required this.lat,
    required this.lng,
    this.capacity,
    this.phone,
  });

  final String id;
  final String name;
  // Thai name for the Thai UI (DRAFT, owner to review); null falls back to [name].
  final String? nameTh;
  final double lat;
  final double lng;
  // How many people it holds, or null when not published.
  final int? capacity;

  // A number to ask about space, or null.
  final String? phone;

  // Builds a shelter from a decoded JSON map.
  factory Shelter.fromJson(Map<String, dynamic> json) => Shelter(
    id: json['id'] as String,
    name: json['name'] as String,
    nameTh: json['nameTh'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    capacity: json['capacity'] as int?,
    phone: json['phone'] as String?,
  );

  // Converts the shelter to a JSON-friendly map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameTh': nameTh,
    'lat': lat,
    'lng': lng,
    'capacity': capacity,
    'phone': phone,
  };
}
