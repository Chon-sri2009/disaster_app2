import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/alert_level.dart';
import '../models/official_alert.dart';
import 'alert_rules.dart';
import 'http_get.dart';
import 'storage_service.dart';

// Holds the last alert snapshot, caches it for offline use, and says how old it is (plan 7.5).
// The snapshot URL is empty until a backend exists (decision D1); then nothing is fetched.
class AlertService extends ChangeNotifier {
  AlertService(
    this._storage, {
    this.snapshotUrl = '',
    Future<String> Function(Uri url)? fetcher,
    DateTime Function()? clock,
  }) : _fetch = fetcher ?? httpGetText,
       _clock = clock ?? DateTime.now {
    final cached = _storage.snapshot;
    if (cached != null) {
      try {
        _apply(cached.json, cached.fetchedAt);
      } catch (_) {
        // A broken cache is ignored; the next refresh replaces it.
      }
    }
  }

  // Alerts older than this without a refresh are shown as stale.
  static const staleAfter = Duration(minutes: 30);

  final StorageService _storage;
  final String snapshotUrl;
  final Future<String> Function(Uri url) _fetch;
  final DateTime Function() _clock;

  List<OfficialAlert> _alerts = const [];
  DateTime? _fetchedAt;
  int _skippedFiles = 0;
  Timer? _timer;
  bool _busy = false;

  bool get hasSnapshot => _fetchedAt != null;
  // The time of the DATA: when the backend built the snapshot, not when the phone downloaded it.
  // A dead backend keeps serving its last snapshot, so download time would hide that it is old.
  DateTime? get fetchedAt => _fetchedAt;
  // Listed alert files the backend could not read in its last poll: the list may be missing
  // a live warning, so it must not read as "no alerts".
  int get skippedFiles => _skippedFiles;
  bool get isStale =>
      _fetchedAt == null ||
      _skippedFiles > 0 ||
      _clock().difference(_fetchedAt!) > staleAfter;

  List<OfficialAlert> get visibleAlerts =>
      AlertRules.visible(_alerts, _clock().toUtc());

  // [provinceCode] is the user's province, or null when unknown (then codes never match).
  AlertLevel levelAt(LatLng point, {String? provinceCode}) => AlertRules.levelAt(
    _alerts,
    point,
    _clock().toUtc(),
    provinceCode: provinceCode,
  );

  // Re-downloads every [every] while the app runs; a refresh still running is skipped.
  void startAutoRefresh({Duration every = const Duration(minutes: 2)}) {
    _timer ??= Timer.periodic(every, (_) => refresh());
  }

  // Downloads a fresh snapshot over HTTPS. On any failure the old snapshot is kept.
  Future<void> refresh() async {
    final url = Uri.tryParse(snapshotUrl);
    if (url == null || url.scheme != 'https' || _busy) return;
    _busy = true;
    try {
      final body = await _fetch(url);
      final now = _clock();
      // A live body must say when it was built; without that its age is unknown, and
      // download time would make a dead backend's old data look fresh.
      _apply(body, now, requireGeneratedAt: true);
      await _storage.saveSnapshot(body, now);
    } catch (_) {
      // Offline or bad data is a normal state: keep showing the cached snapshot with its age.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // generatedAt when it is a valid time (a time in the future, from clock skew, must not look
  // fresher than now). Otherwise the download time, but only for an old cache that predates
  // generatedAt: null for a live body, which is then rejected.
  DateTime? _dataTime(
    Object? generatedAt,
    DateTime downloaded, {
    required bool requireGeneratedAt,
  }) {
    final parsed = generatedAt is String
        ? DateTime.tryParse(generatedAt)?.toUtc()
        : null;
    if (parsed == null) return requireGeneratedAt ? null : downloaded;
    final now = _clock().toUtc();
    return parsed.isAfter(now) ? now : parsed;
  }

  void _apply(
    String json,
    DateTime fetchedAt, {
    bool requireGeneratedAt = false,
  }) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final alerts = [
      for (final a in map['alerts'] as List)
        OfficialAlert.fromJson(a as Map<String, dynamic>),
    ];
    final time = _dataTime(
      map['generatedAt'],
      fetchedAt,
      requireGeneratedAt: requireGeneratedAt,
    );
    if (time == null) throw const FormatException('no generatedAt');
    final skipped = map['skippedFiles'];
    _alerts = alerts;
    _fetchedAt = time;
    _skippedFiles = skipped is int && skipped > 0 ? skipped : 0;
    notifyListeners();
  }
}
