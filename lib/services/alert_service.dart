import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/alert_level.dart';
import '../models/official_alert.dart';
import 'alert_rules.dart';
import 'storage_service.dart';

// Holds the last alert snapshot, caches it for offline use, and says how old it is (plan 7.5).
// The snapshot URL is empty until a backend exists (decision D1); then nothing is fetched.
class AlertService extends ChangeNotifier {
  AlertService(
    this._storage, {
    this.snapshotUrl = '',
    Future<String> Function(Uri url)? fetcher,
    DateTime Function()? clock,
  }) : _fetch = fetcher ?? _httpGet,
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

  bool get hasSnapshot => _fetchedAt != null;
  DateTime? get fetchedAt => _fetchedAt;
  bool get isStale =>
      _fetchedAt == null || _clock().difference(_fetchedAt!) > staleAfter;

  List<OfficialAlert> get visibleAlerts =>
      AlertRules.visible(_alerts, _clock().toUtc());

  AlertLevel levelAt(LatLng point) =>
      AlertRules.levelAt(_alerts, point, _clock().toUtc());

  // Downloads a fresh snapshot over HTTPS. On any failure the old snapshot is kept.
  Future<void> refresh() async {
    final url = Uri.tryParse(snapshotUrl);
    if (url == null || url.scheme != 'https') return;
    try {
      final body = await _fetch(url);
      final now = _clock();
      _apply(body, now);
      await _storage.saveSnapshot(body, now);
    } catch (_) {
      // Offline or bad data is a normal state: keep showing the cached snapshot with its age.
    }
  }

  void _apply(String json, DateTime fetchedAt) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    _alerts = [
      for (final a in map['alerts'] as List)
        OfficialAlert.fromJson(a as Map<String, dynamic>),
    ];
    _fetchedAt = fetchedAt;
    notifyListeners();
  }

  static Future<String> _httpGet(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final res = await (await client.getUrl(url)).close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      return await utf8.decodeStream(res);
    } finally {
      client.close();
    }
  }
}
