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
}
