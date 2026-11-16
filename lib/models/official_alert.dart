import 'package:latlong2/latlong.dart';

import 'alert_level.dart';

// One alert in the normalised snapshot the backend will publish (plan 7.2).
// Official text is kept per language and never machine-translated.
class OfficialAlert {
  const OfficialAlert({
    required this.id,
    required this.sender,
    required this.status,
    required this.msgType,
    required this.level,
    required this.headline,
    required this.sent,
    this.expires,
    this.references = const [],
    this.polygons = const [],
  });

  final String id;
  final String sender;
  final String status; // CAP: Actual, Test, Exercise, ...
  final String msgType; // CAP: Alert, Update, Cancel
  final AlertLevel level;
  final Map<String, String> headline; // language code -> official text
  final DateTime sent;
  final DateTime? expires;
  final List<String> references; // ids this message replaces or cancels
  final List<List<LatLng>> polygons;

  // Used when the agency gives no expiry; the UI must label such alerts.
  static const defaultLifetime = Duration(hours: 6);

  bool get hasExpiry => expires != null;
  DateTime get effectiveExpiry => expires ?? sent.add(defaultLifetime);

  factory OfficialAlert.fromJson(Map<String, dynamic> j) => OfficialAlert(
    id: j['id'] as String,
    sender: j['sender'] as String,
    status: j['status'] as String,
    msgType: j['msgType'] as String,
    level: AlertLevel.values.byName(j['level'] as String),
    headline: Map<String, String>.from(j['headline'] as Map),
    sent: DateTime.parse(j['sent'] as String).toUtc(),
    expires: j['expires'] == null
        ? null
        : DateTime.parse(j['expires'] as String).toUtc(),
    references: List<String>.from(j['references'] as List? ?? const []),
    polygons: [
      for (final ring in (j['polygons'] as List? ?? const []))
        // Snapshot rings are GeoJSON-style [lon, lat] pairs.
        [
          for (final p in ring as List)
            LatLng(
              ((p as List)[1] as num).toDouble(),
              (p[0] as num).toDouble(),
            ),
        ],
    ],
  );
}
