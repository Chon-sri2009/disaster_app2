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

  // Opens turn-by-turn directions in the phone's map app.
  static Future<bool> navigate(double lat, double lng) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    }),
    mode: LaunchMode.externalApplication,
  );
}
