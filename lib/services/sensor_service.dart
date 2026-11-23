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
      _timer = Timer.periodic(pollEvery, (_) => _tick());
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
  // Normal clock jitter or an NTP nudge backwards is tolerated up to this much.
  static const clockBackSlack = Duration(minutes: 1);

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
  // A download can finish after the screen is gone: then nothing may notify or be written.
  bool _disposed = false;
  // Last staleness the listeners were told about; starts true because no data is stale.
  bool _wasStale = true;

  // True when a real backend address is configured.
  bool get isLive => Uri.tryParse(snapshotUrl)?.scheme == 'https';
  // Fake data is for debug builds only.
  bool get isDemo => !isLive && kDebugMode;

  List<StationStatus> get stations => _stations;
  // The time of the DATA (the server's `generatedAt`), not of the download: a fresh download
  // of old data must read as old (R-F8).
  DateTime? get fetchedAt => _fetchedAt;
  // A negative age means the phone clock moved back after the download (R-F6). The age is
  // then unknown, so old data must not stay fresh: stale, beyond a small slack for jitter.
  bool get isStale {
    final fetched = _fetchedAt;
    if (fetched == null) return true;
    final age = _clock().difference(fetched);
    return age > staleAfter || age < -clockBackSlack;
  }

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

  // The poll beat. Check staleness first and on its own: a hung fetch keeps _busy true, and
  // an old Safe must still turn into "no data" without waiting for it.
  void _tick() {
    _notifyIfStaleChanged();
    refresh();
  }

  // Time alone makes data stale, so nothing else would notify. Only a flip notifies: no
  // rebuild on every tick.
  void _notifyIfStaleChanged() {
    if (_disposed) return;
    final stale = isStale;
    if (stale != _wasStale) {
      _wasStale = stale;
      notifyListeners();
    }
  }

  // Downloads /snapshot. On any failure the last good data stays, with its age.
  Future<void> refresh() async {
    if (!isLive || _busy) return;
    _busy = true;
    try {
      final body = await _fetch(Uri.parse(snapshotUrl));
      if (_disposed) return;
      final map = jsonDecode(body) as Map<String, dynamic>;
      // Parse everything first: a body with no usable time is rejected whole, so the old
      // data keeps its own age and nothing is half-updated.
      final time = _dataTime(map['generatedAt']);
      final stations = [
        for (final s in map['stations'] as List)
          StationStatus.fromJson(s as Map<String, dynamic>),
      ];
      _stations = stations;
      _fetchedAt = time;
      _wasStale = isStale;
      notifyListeners();
    } catch (_) {
      // Offline or bad data is a normal state: keep the old snapshot; isStale reports its age.
      // Time may have made it stale meanwhile, so tell the listeners.
      _notifyIfStaleChanged();
    } finally {
      _busy = false;
    }
  }

  // Only an explicit-UTC string counts: no zone parses as local time (7 h off in Bangkok).
  // A future time is kept as is (isStale decides), never clamped to now.
  static DateTime _dataTime(Object? raw) {
    if (raw is! String) throw const FormatException('generatedAt missing');
    final t = DateTime.tryParse(raw);
    if (t == null || !t.isUtc) throw const FormatException('generatedAt invalid');
    return t;
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
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }
}
