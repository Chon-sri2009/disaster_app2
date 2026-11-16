import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'storage_service.dart';

// The outcome of a GPS request: a point (fresh or saved) and/or a readable error.
class LocationResult {
  const LocationResult({this.point, this.fromCache = false, this.error});

  final LatLng? point;
  final bool fromCache;
  final String? error;
}

// A problem with GPS that has a message safe to show to the user.
class _LocationProblem implements Exception {
  const _LocationProblem(this.message);

  final String message;
}

// Reads the phone's GPS position and never throws; falls back to the last saved position.
class LocationService {
  LocationService(this._storage);

  final StorageService _storage;

  // Asks for permission if needed, reads GPS, and saves the position for later.
  Future<LocationResult> getCurrent() async {
    String error;
    try {
      final point = await _readGps();
      await _storage.saveLastPosition(point);
      return LocationResult(point: point);
    } on _LocationProblem catch (e) {
      error = e.message;
    } on TimeoutException {
      error =
          'GPS took too long to answer. Try again outside or near a window.';
    } catch (_) {
      error = 'Could not read the GPS position on this device.';
    }

    final saved = _storage.lastPosition;
    return LocationResult(point: saved, fromCache: saved != null, error: error);
  }

  // Checks that location is on and allowed, then returns the current position.
  Future<LatLng> _readGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationProblem(
        'Location is turned off. Please turn on GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationProblem('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationProblem(
        'Location permission is blocked. Enable it in the phone settings.',
      );
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
