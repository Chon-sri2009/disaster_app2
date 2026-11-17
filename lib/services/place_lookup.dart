import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../l10n/app_lang.dart';
import '../models/shelter.dart';

// Where a position is, in words: a street address when one could be found, otherwise the
// nearest known place. Coordinates are never shown to people.
class Place {
  const Place({this.address, this.nearest, this.meters});

  // A street address such as "12 ถนนจรัญสนิทวงศ์, บางขุนศรี, บางกอกน้อย".
  final String? address;

  // The closest saved shelter, used when no address is known (for example offline).
  final Shelter? nearest;
  final double? meters;

  bool get isEmpty => address == null && nearest == null;
}

// Turns a position into an address; null when none is known. Swappable so tests need no network.
typedef AddressLookup = Future<String?> Function(LatLng point, AppLang lang);

// Asks OpenStreetMap's Nominatim service for the address at a position. The position leaves the
// phone, so this only runs when the person asks for their location, and any failure (no signal,
// slow answer, nothing found) simply returns null so the offline fallback takes over.
Future<String?> nominatimLookup(LatLng point, AppLang lang) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    final request = await client.getUrl(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': lang.code,
      }),
    );
    // Nominatim's usage policy asks every app to identify itself.
    request.headers.set(HttpHeaders.userAgentHeader, 'disaster_app2');
    final response = await request.close();
    if (response.statusCode != 200) return null;
    final json = jsonDecode(
      await response.transform(utf8.decoder).join(),
    ) as Map<String, dynamic>;
    return formatAddress(json['address'] as Map<String, dynamic>?);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

// House number and street first, then the area, narrowest to widest. Null when there is nothing.
String? formatAddress(Map<String, dynamic>? a) {
  if (a == null) return null;
  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = a[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  final street = [
    pick(['house_number']),
    pick(['road']),
  ].whereType<String>().join(' ');
  final parts = <String>{
    if (street.isNotEmpty) street,
    ?pick(['neighbourhood', 'suburb', 'quarter']),
    ?pick(['city_district', 'district', 'county']),
    ?pick(['city', 'town', 'village', 'municipality']),
    ?pick(['state']),
  };
  return parts.isEmpty ? null : parts.join(', ');
}
