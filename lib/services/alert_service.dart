import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/alert_history_entry.dart';
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
    _history = _loadHistory();
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
  late List<HistoryEntry> _history;
  Timer? _timer;
  bool _busy = false;

  // Notices that were shown and have ended, newest first. Read-only record for the history
  // screen: it must never feed visibleAlerts, levelAt or Home's level.
  List<HistoryEntry> get history => List.unmodifiable(_history);

  static const maxHistory = 50;
  static const historyKeep = Duration(days: 30);
  // A notice that vanished with no proof it ended is followed this long, then forgotten.
  static const unprovenKeep = Duration(days: 7);

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
  AlertLevel levelAt(LatLng point, {String? provinceCode}) =>
      AlertRules.levelAt(
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
    try {
      _recordEnded(alerts);
    } catch (_) {
      // History is a convenience; it must never break the alerts themselves.
    }
    notifyListeners();
  }

  List<HistoryEntry> _loadHistory() {
    final out = <HistoryEntry>[];
    for (final j in _storage.alertHistory) {
      try {
        out.add(HistoryEntry.fromJson(j));
      } catch (_) {
        // Skip one bad entry, keep the rest.
      }
    }
    return out;
  }

  // Compares the notices seen as visible so far with this snapshot. A notice is recorded as
  // ended only with proof: a Cancel or Update in the snapshot, or its expiry time passed.
  // A missing notice alone proves nothing (a partial or stale list can omit it).
  void _recordEnded(List<OfficialAlert> alerts) {
    final now = _clock().toUtc();
    final visibleNow = AlertRules.visible(alerts, now);
    final visibleIds = {for (final a in visibleNow) a.id};
    final cancelled = <String>{};
    final replaced = <String>{};
    for (final a in alerts) {
      if (a.status != 'Actual') continue; // Test or Exercise proves nothing
      if (a.msgType == 'Cancel') cancelled.addAll(a.references);
      if (a.msgType == 'Update') replaced.addAll(a.references);
    }

    final tracked = <AlertRecord>[];
    for (final j in _storage.trackedAlerts) {
      try {
        tracked.add(AlertRecord.fromJson(j));
      } catch (_) {
        // Skip one bad record.
      }
    }

    final keep = <String, AlertRecord>{};
    final ended = <HistoryEntry>[];
    for (final r in tracked) {
      if (visibleIds.contains(r.id)) continue;
      // Some files could not be read: nothing may be ended by absence this round.
      if (_skippedFiles > 0) {
        keep[r.id] = r;
        continue;
      }
      EndReason? reason;
      var endedAt = now;
      if (cancelled.contains(r.id)) {
        reason = EndReason.cancelled;
      } else if (replaced.contains(r.id)) {
        reason = EndReason.replaced;
      } else if (!now.isBefore(r.effectiveExpiry)) {
        reason = EndReason.expired;
        endedAt = r.effectiveExpiry;
      }
      if (reason != null) {
        ended.add(HistoryEntry(record: r, endedAt: endedAt, reason: reason));
      } else {
        final since = r.missingSince ?? now;
        if (now.difference(since) <= unprovenKeep) {
          keep[r.id] = r.withMissingSince(since);
        }
      }
    }
    for (final a in visibleNow) {
      keep[a.id] = AlertRecord.of(a);
    }

    final known = {for (final e in _history) e.record.id};
    final merged = [
      ..._history,
      for (final e in ended)
        if (known.add(e.record.id)) e,
    ]..removeWhere((e) => now.difference(e.endedAt) > historyKeep);
    merged.sort((x, y) => y.endedAt.compareTo(x.endedAt));
    final next = merged.take(maxHistory).toList();

    final changed =
        next.length != _history.length ||
        [for (final e in next) e.record.id].join() !=
            [for (final e in _history) e.record.id].join();
    _history = next;
    unawaited(
      _storage.saveTrackedAlerts([for (final r in keep.values) r.toJson()]),
    );
    if (changed || ended.isNotEmpty) {
      unawaited(_storage.saveAlertHistory([for (final e in next) e.toJson()]));
    }
  }
}
