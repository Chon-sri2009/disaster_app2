import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_lang.dart';
import '../models/damage_report.dart';
import '../models/shelter.dart';

// Saves shelters, damage reports and the last GPS position on the phone so they work offline.
class StorageService extends ChangeNotifier {
  StorageService._(this._prefs) {
    _reports = _loadReports();
  }

  static const _sheltersKey = 'shelters';
  static const _reportsKey = 'reports';
  static const _lastPositionKey = 'last_position';
  static const _snapshotKey = 'alert_snapshot';
  static const _trackedKey = 'alert_tracked';
  static const _historyKey = 'alert_history';
  static const _languageKey = 'language';
  static const _themeKey = 'theme';

  final SharedPreferences _prefs;
  late List<DamageReport> _reports;

  // Opens the phone storage; call once at app start.
  static Future<StorageService> create() async =>
      StorageService._(await SharedPreferences.getInstance());

  // The UI language; Thai until the user picks English.
  AppLang get language => AppLang.fromCode(_prefs.getString(_languageKey));

  Future<void> setLanguage(AppLang lang) async {
    await _prefs.setString(_languageKey, lang.code);
    notifyListeners();
  }

  // Day board, night board, or follow the phone (the default).
  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  // Newest report first.
  List<DamageReport> get reports => List.unmodifiable(_reports);

  // Shelters from the offline cache (empty if nothing was cached yet).
  List<Shelter> get shelters {
    final text = _prefs.getString(_sheltersKey);
    if (text == null) return [];
    try {
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .map((e) => Shelter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Stores the shelter list so the map screen can show it without internet.
  Future<void> saveShelters(List<Shelter> shelters) async {
    await _prefs.setString(
      _sheltersKey,
      jsonEncode(shelters.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  // Adds a new report at the top of the list and saves all reports.
  Future<void> addReport(DamageReport report) async {
    _reports = [report, ..._reports];
    await _prefs.setString(
      _reportsKey,
      jsonEncode(_reports.map((r) => r.toJson()).toList()),
    );
    notifyListeners();
  }

  // The last GPS position that was read successfully, or null.
  LatLng? get lastPosition {
    final text = _prefs.getString(_lastPositionKey);
    if (text == null) return null;
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      return LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  // Remembers the latest GPS position for when GPS fails later.
  Future<void> saveLastPosition(LatLng point) async {
    await _prefs.setString(
      _lastPositionKey,
      jsonEncode({'lat': point.latitude, 'lng': point.longitude}),
    );
  }

  // Last downloaded alert snapshot (raw JSON) and when it was fetched, or null.
  ({String json, DateTime fetchedAt})? get snapshot {
    final text = _prefs.getString(_snapshotKey);
    if (text == null) return null;
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      return (
        json: map['json'] as String,
        fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(String json, DateTime fetchedAt) =>
      _prefs.setString(
        _snapshotKey,
        jsonEncode({
          'json': json,
          'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        }),
      );

  // Notices seen as visible and not yet ended (compact JSON records); [] when missing or broken.
  List<Map<String, dynamic>> get trackedAlerts => _jsonList(_trackedKey);

  Future<void> saveTrackedAlerts(List<Map<String, dynamic>> records) =>
      _prefs.setString(_trackedKey, jsonEncode(records));

  // Ended notices, newest first (compact JSON); [] when missing or broken.
  List<Map<String, dynamic>> get alertHistory => _jsonList(_historyKey);

  Future<void> saveAlertHistory(List<Map<String, dynamic>> entries) =>
      _prefs.setString(_historyKey, jsonEncode(entries));

  List<Map<String, dynamic>> _jsonList(String key) {
    final text = _prefs.getString(key);
    if (text == null) return [];
    try {
      return [
        for (final e in jsonDecode(text) as List<dynamic>)
          e as Map<String, dynamic>,
      ];
    } catch (_) {
      return [];
    }
  }

  // Reads saved reports; a broken save returns an empty list instead of crashing.
  List<DamageReport> _loadReports() {
    final text = _prefs.getString(_reportsKey);
    if (text == null) return [];
    try {
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .map((e) => DamageReport.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
