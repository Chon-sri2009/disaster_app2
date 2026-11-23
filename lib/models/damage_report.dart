// A damage report written by a resident; saved locally as JSON.
class DamageReport {
  const DamageReport({
    required this.id,
    required this.category,
    required this.note,
    required this.createdAt,
    this.lat,
    this.lng,
    this.address,
    this.photoPath,
  });

  final String id;
  final String category;
  final String note;
  final DateTime createdAt;
  final double? lat;
  final double? lng;

  // Where the damage is, in words (found from GPS or typed by the person).
  final String? address;
  final String? photoPath;

  // Builds a report from a decoded JSON map.
  factory DamageReport.fromJson(Map<String, dynamic> json) => DamageReport(
    id: json['id'] as String,
    category: json['category'] as String,
    note: json['note'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    address: json['address'] as String?,
    photoPath: json['photoPath'] as String?,
  );

  // Converts the report to a JSON-friendly map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'lat': lat,
    'lng': lng,
    'address': address,
    'photoPath': photoPath,
  };
}
