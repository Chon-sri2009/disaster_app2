import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'nearby.dart';
import 'place_lookup.dart';
import 'storage_service.dart';

// Why GPS failed. The words for each case live in l10n (context.locationError).
enum LocationIssue { serviceOff, denied, blocked, timeout, unknown }

// The outcome of a GPS request: a point (fresh or saved) and/or the reason it failed.
class LocationResult {
  const LocationResult({this.point, this.fromCache = false, this.issue});

  final LatLng? point;
  final bool fromCache;
  final LocationIssue? issue;
}

// A known problem with GPS.
class _LocationProblem implements Exception {
  const _LocationProblem(this.issue);

  final LocationIssue issue;
}

// Reads the phone's GPS position and never throws; falls back to the last saved position.
class LocationService {
  LocationService(this._storage, {this._lookup = nominatimLookup});

  final StorageService _storage;
  final AddressLookup _lookup;

  // Says where a position is: the street address when it can be found quickly, otherwise the
  // nearest saved shelter (works offline). Never throws.
  Future<Place> describe(LatLng point) async {
    String? address;
    try {
      address = await _lookup(
        point,
        _storage.language,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (address != null) return Place(address: address);
    final shelters = Nearby.sorted(_storage.shelters, point);
    if (shelters.isEmpty) return const Place();
    return Place(
      nearest: shelters.first,
      meters: Nearby.metersTo(point, shelters.first),
    );
  }

  // The last position we saved, or null if GPS has never worked.
  LatLng? get lastKnown => _storage.lastPosition;

  // Asks for permission if needed, reads GPS, and saves the position for later.
  Future<LocationResult> getCurrent() async {
    LocationIssue issue;
    try {
      final point = await _readGps();
      await _storage.saveLastPosition(point);
      return LocationResult(point: point);
    } on _LocationProblem catch (e) {
      issue = e.issue;
    } on TimeoutException {
      issue = LocationIssue.timeout;
    } catch (_) {
      issue = LocationIssue.unknown;
    }

    final saved = _storage.lastPosition;
    return LocationResult(point: saved, fromCache: saved != null, issue: issue);
  }

  // Checks that location is on and allowed, then returns the current position.
  Future<LatLng> _readGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationProblem(LocationIssue.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationProblem(LocationIssue.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationProblem(LocationIssue.blocked);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}
