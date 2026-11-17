import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/sensor_reading.dart';
import '../models/sensor_station.dart';
import '../models/shelter.dart';

// All fake data in one place; replace these members with real ESP32/Firebase data later.
class MockData {
  MockData._();

  // Safe limits for each sensor.
  static const double waterLimitCm = 150;
  static const double vibrationLimitG = 0.5;

  // Water at or above this share of its limit counts as "Watch".
  static const double watchRatio = 0.7;

  // Slider range used by the demo simulator.
  static const double waterMaxCm = 250;

  // Map centre (Bangkok, as an example area).
  static const LatLng areaCenter = LatLng(13.7563, 100.5018);

  // True while the saved list is still this sample list, so screens can label it as such.
  static bool isDemoShelterList(List<Shelter> list) =>
      list.isNotEmpty && list.every((s) => shelters.any((m) => m.id == s.id));

  static const List<Shelter> shelters = [
    Shelter(
      id: 's1',
      name: 'City Hall Shelter',
      lat: 13.7600,
      lng: 100.4960,
      capacity: 300,
    ),
    Shelter(
      id: 's2',
      name: 'Green Hill School',
      lat: 13.7520,
      lng: 100.5100,
      capacity: 200,
    ),
    Shelter(
      id: 's3',
      name: 'Community Sports Hall',
      lat: 13.7650,
      lng: 100.5080,
      capacity: 450,
    ),
    Shelter(
      id: 's4',
      name: 'Sunrise Temple Hall',
      lat: 13.7480,
      lng: 100.4950,
      capacity: 150,
    ),
    Shelter(
      id: 's5',
      name: 'North District Clinic',
      lat: 13.7700,
      lng: 100.5020,
      capacity: 80,
    ),
  ];

  static const List<SensorStation> stations = [
    SensorStation(
      id: 'w1',
      name: 'River Gate Station',
      lat: 13.7545,
      lng: 100.4990,
    ),
    SensorStation(
      id: 'w2',
      name: 'Old Bridge Station',
      lat: 13.7580,
      lng: 100.5050,
    ),
    SensorStation(
      id: 'v1',
      name: 'Hillside Vibration Station',
      lat: 13.7620,
      lng: 100.5120,
    ),
  ];

  static final Random _random = Random();

  // The first reading shown when the app starts.
  static SensorReading startReading() =>
      SensorReading(waterCm: 80, vibrationG: 0.1, time: DateTime.now());

  // Makes the next fake reading: water drifts gently back towards 80 cm, vibration sometimes spikes.
  static SensorReading nextReading(SensorReading previous) {
    final drift = (80 - previous.waterCm) * 0.03 + _random.nextDouble() * 6 - 3;
    final water = (previous.waterCm + drift).clamp(0.0, waterMaxCm).toDouble();
    final spike = _random.nextInt(20) == 0;
    final vibration = spike
        ? 0.55 + _random.nextDouble() * 0.3
        : 0.05 + _random.nextDouble() * 0.2;
    return SensorReading(
      waterCm: water,
      vibrationG: vibration,
      time: DateTime.now(),
    );
  }
}
