import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/place_lookup.dart';
import 'package:disaster_app2/services/storage_service.dart';

void main() {
  test(
    'an address reads house and street first, then the area, no repeats',
    () {
      expect(
        formatAddress({
          'house_number': '12',
          'road': 'ถนนจรัญสนิทวงศ์',
          'suburb': 'บางขุนศรี',
          'city_district': 'บางกอกน้อย',
          'city': 'กรุงเทพมหานคร',
          'state': 'กรุงเทพมหานคร',
        }),
        '12 ถนนจรัญสนิทวงศ์, บางขุนศรี, บางกอกน้อย, กรุงเทพมหานคร',
      );
      // What Nominatim really returns in Bangkok: both the แขวง and the เขต must survive.
      expect(
        formatAddress({
          'house_number': '74',
          'road': 'ถนนจักรพงษ์',
          'quarter': 'แขวงตลาดยอด',
          'suburb': 'เขตพระนคร',
          'city': 'กรุงเทพมหานคร',
        }),
        '74 ถนนจักรพงษ์, แขวงตลาดยอด, เขตพระนคร, กรุงเทพมหานคร',
      );
      expect(formatAddress({}), isNull);
      expect(formatAddress(null), isNull);
    },
  );

  test('without an address the nearest shelter names the place', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.saveShelters(MockData.shelters);
    final service = LocationService(storage, lookup: (_, _) async => null);
    final place = await service.describe(const LatLng(13.7600, 100.4960));
    expect(place.address, isNull);
    expect(place.nearest, isNotNull);
    expect(place.meters, lessThan(100));
  });

  test('a found address wins over the nearest shelter', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final service = LocationService(
      storage,
      lookup: (_, _) async => '9 ถนนสุขุมวิท',
    );
    final place = await service.describe(const LatLng(13.76, 100.49));
    expect(place.address, '9 ถนนสุขุมวิท');
  });
}
