import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

// Opens the phone's dialler or SMS composer. The user always presses call/send;
// the app never contacts anyone silently (plan 7.7).
abstract final class EmergencyLauncher {
  static Future<bool> call(String number) =>
      launchUrl(Uri(scheme: 'tel', path: number));

  // SMS composer pre-filled with the body; `recipients` may be empty.
  static Future<bool> sms(List<String> recipients, String body) => launchUrl(
    Uri(
      scheme: 'sms',
      path: recipients.join(','),
      queryParameters: {'body': body},
    ),
  );

  // Links to try for directions, best first: the Google Maps app itself (no
  // browser, no chooser), then the web link, which any map app or browser takes.
  static List<Uri> navigationUris(
    double lat,
    double lng, {
    required bool ios,
  }) => [
    if (ios)
      Uri(
        scheme: 'comgooglemaps',
        host: '',
        queryParameters: {'daddr': '$lat,$lng', 'directionsmode': 'driving'},
      )
    else
      Uri.parse('google.navigation:q=$lat,$lng'),
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    }),
  ];

  // Opens turn-by-turn directions, in the Google Maps app when it is installed.
  static Future<bool> navigate(double lat, double lng) async {
    for (final uri in navigationUris(lat, lng, ios: Platform.isIOS)) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // No app handles this link: try the next one.
      }
    }
    return false;
  }
}
