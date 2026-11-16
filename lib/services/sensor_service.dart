import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/alert_level.dart';
import '../models/sensor_reading.dart';

// Publishes a new mock reading every 2 seconds and tells the screens when it changes.
class SensorService extends ChangeNotifier {
  SensorService() {
    _latest = MockData.startReading();
    _subscription = _controller.stream.listen((reading) {
      _latest = reading;
      notifyListeners();
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _controller.add(MockData.nextReading(_latest));
    });
  }

  // Swap this stream's source for ESP32/Firebase data later.
  final StreamController<SensorReading> _controller =
      StreamController.broadcast();
  late final StreamSubscription<SensorReading> _subscription;
  late final Timer _timer;
  late SensorReading _latest;

  SensorReading get latest => _latest;

  bool get waterOverLimit => _latest.waterCm >= MockData.waterLimitCm;
  bool get vibrationOverLimit => _latest.vibrationG >= MockData.vibrationLimitG;

  // Danger if any sensor passed its limit, Watch if water is close to it, otherwise Safe.
  AlertLevel get level {
    if (waterOverLimit || vibrationOverLimit) return AlertLevel.danger;
    if (_latest.waterCm >= MockData.waterLimitCm * MockData.watchRatio) {
      return AlertLevel.watch;
    }
    return AlertLevel.safe;
  }

  // Demo helper: forces the water reading to a value chosen with the slider.
  void simulateWater(double cm) {
    _controller.add(
      SensorReading(
        waterCm: cm,
        vibrationG: _latest.vibrationG,
        time: DateTime.now(),
      ),
    );
  }

  // Stops the timer and stream when the app closes.
  @override
  void dispose() {
    _timer.cancel();
    _subscription.cancel();
    _controller.close();
    super.dispose();
  }
}
