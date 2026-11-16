import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/alert_level.dart';
import '../models/sensor_reading.dart';
import '../models/station_status.dart';
import 'http_get.dart';

// Two modes. Live: polls the backend's /snapshot (set by SENSOR_SNAPSHOT_URL). Demo (debug
// builds with no URL): publishes a fake reading every 2 seconds. A release build with no URL
// has neither, so `level` is null: the UI says "no live data" and never shows a made-up Safe.
class SensorService extends ChangeNotifier {
  SensorService({
    this.snapshotUrl = '',
    Future<String> Function(Uri url)? fetcher,
    DateTime Function()? clock,
  }) : _fetch = fetcher ?? httpGetText,
       _clock = clock ?? DateTime.now {
    _latest = MockData.startReading();
    if (isLive) {
      refresh();
      _timer = Timer.periodic(pollEvery, (_) => refresh());
    } else if (isDemo) {
      _subscription = _controller.stream.listen((reading) {
        _latest = reading;
        notifyListeners();
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        _controller.add(MockData.nextReading(_latest));
      });
    }
  }

  static const pollEvery = Duration(seconds: 30);
  // The backend marks a station stale after 2 min; the phone allows for slow polling.
  static const staleAfter = Duration(minutes: 5);

  final String snapshotUrl;
  final Future<String> Function(Uri url) _fetch;
  final DateTime Function() _clock;

  final StreamController<SensorReading> _controller =
      StreamController.broadcast();
  StreamSubscription<SensorReading>? _subscription;
  Timer? _timer;
  late SensorReading _latest;
  List<StationStatus> _stations = const [];
  DateTime? _fetchedAt;
  bool _busy = false;

  // True when a real backend address is configured.
  bool get isLive => Uri.tryParse(snapshotUrl)?.scheme == 'https';
  // Fake data is for debug builds only.
  bool get isDemo => !isLive && kDebugMode;

  List<StationStatus> get stations => _stations;
  DateTime? get fetchedAt => _fetchedAt;
  bool get isStale =>
      _fetchedAt == null || _clock().difference(_fetchedAt!) > staleAfter;

  // Demo-mode readings (the live mode has no vibration or fixed limits).
  SensorReading get latest => _latest;
  bool get waterOverLimit => _latest.waterCm >= MockData.waterLimitCm;
  bool get vibrationOverLimit => _latest.vibrationG >= MockData.vibrationLimitG;

  // The level to show, or null for "no live data". Live: the worst usable station. A stale
  // snapshot can still say Watch or Danger (worse news is never hidden) but never Safe.
  AlertLevel? get level {
    if (isDemo) return _demoLevel;
    if (!isLive) return null;
    AlertLevel? worst;
    for (final s in _stations) {
      final l = s.level;
      if (l != null && (worst == null || l.index > worst.index)) worst = l;
    }
    if (worst == AlertLevel.safe && isStale) return null;
    return worst;
  }

  // Danger if any sensor passed its limit, Watch if water is close to it, otherwise Safe.
  AlertLevel get _demoLevel {
    if (waterOverLimit || vibrationOverLimit) return AlertLevel.danger;
    if (_latest.waterCm >= MockData.waterLimitCm * MockData.watchRatio) {
      return AlertLevel.watch;
    }
    return AlertLevel.safe;
  }

  // Downloads /snapshot. On any failure the last good data stays, with its age.
  Future<void> refresh() async {
    if (!isLive || _busy) return;
    _busy = true;
    try {
      final map = jsonDecode(await _fetch(Uri.parse(snapshotUrl)));
      _stations = [
        for (final s in (map as Map<String, dynamic>)['stations'] as List)
          StationStatus.fromJson(s as Map<String, dynamic>),
      ];
      _fetchedAt = _clock();
      notifyListeners();
    } catch (_) {
      // Offline or bad data is a normal state: keep the old snapshot; isStale reports its age.
    } finally {
      _busy = false;
    }
  }

  // Demo helper: forces the water reading to a value chosen with the slider.
  void simulateWater(double cm) {
    if (!isDemo) return;
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
    _timer?.cancel();
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }
}
