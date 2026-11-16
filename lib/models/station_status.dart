import 'alert_level.dart';

// One sensor station as published by the backend's /snapshot.
// `level` is null when the station is stale, offline or faulty: that is "no data", never Safe.
class StationStatus {
  const StationStatus({
    required this.id,
    required this.name,
    required this.level,
    this.waterCm,
    this.readingTime,
  });

  final String id;
  final String name;
  final AlertLevel? level;
  final double? waterCm;
  final DateTime? readingTime;

  factory StationStatus.fromJson(Map<String, dynamic> j) {
    final band = j['band'];
    final usable = j['status'] == 'ok';
    return StationStatus(
      id: j['id'] as String,
      name: (j['name'] as String?) ?? j['id'] as String,
      level: usable && band is String && band != 'unknown'
          ? AlertLevel.values.byName(band)
          : null,
      waterCm: (j['waterCm'] as num?)?.toDouble(),
      readingTime: j['readingTime'] == null
          ? null
          : DateTime.parse(j['readingTime'] as String).toUtc(),
    );
  }
}
