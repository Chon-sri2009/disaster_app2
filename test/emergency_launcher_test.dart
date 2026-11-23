import 'package:flutter_test/flutter_test.dart';

import 'package:disaster_app2/services/emergency_launcher.dart';

void main() {
  test('Android tries the Google Maps navigation link, then the web link', () {
    final uris = EmergencyLauncher.navigationUris(13.75, 100.5, ios: false);
    expect(uris.map((u) => u.toString()).toList(), [
      'google.navigation:q=13.75,100.5',
      'https://www.google.com/maps/dir/?api=1&destination=13.75%2C100.5',
    ]);
  });

  test('iOS tries the Google Maps app link, then the web link', () {
    final uris = EmergencyLauncher.navigationUris(13.75, 100.5, ios: true);
    expect(uris.first.scheme, 'comgooglemaps');
    expect(uris.first.queryParameters['daddr'], '13.75,100.5');
    expect(uris.last.scheme, 'https');
  });
}
