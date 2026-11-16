// One snapshot of the sensor values (water level in cm, vibration in g) at a point in time.
class SensorReading {
  const SensorReading({
    required this.waterCm,
    required this.vibrationG,
    required this.time,
  });

  final double waterCm;
  final double vibrationG;
  final DateTime time;
}
