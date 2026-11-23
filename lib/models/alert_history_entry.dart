import 'alert_level.dart';
import 'official_alert.dart';

// Why a notice is no longer shown. Only set when the snapshot or the clock proves it.
enum EndReason { expired, cancelled, replaced }

// A notice kept small for storage: no polygons. [missingSince] is only used for tracked
// notices that vanished without proof; history entries do not have it.
class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.level,
    required this.headline,
    required this.sender,
    required this.sent,
    this.expires,
    this.areaCodes = const [],
    this.hadPolygons = false,
    this.missingSince,
  });

  final String id;
  final AlertLevel level;
  final Map<String, String> headline;
  final String sender;
  final DateTime sent;
  final DateTime? expires;
  final List<String> areaCodes;
  // Polygons are dropped for size; this keeps the fact that the area was given as a shape.
  final bool hadPolygons;
  final DateTime? missingSince;

  DateTime get effectiveExpiry =>
      expires ?? sent.add(OfficialAlert.defaultLifetime);

  factory AlertRecord.of(OfficialAlert a) => AlertRecord(
    id: a.id,
    level: a.level,
    headline: a.headline,
    sender: a.sender,
    sent: a.sent,
    expires: a.expires,
    areaCodes: a.areaCodes,
    hadPolygons: a.polygons.isNotEmpty,
  );

  AlertRecord withMissingSince(DateTime? t) => AlertRecord(
    id: id,
    level: level,
    headline: headline,
    sender: sender,
    sent: sent,
    expires: expires,
    areaCodes: areaCodes,
    hadPolygons: hadPolygons,
    missingSince: t,
  );

  // Throws on bad data; callers skip the item.
  factory AlertRecord.fromJson(Map<String, dynamic> j) => AlertRecord(
    id: j['id'] as String,
    level: AlertLevel.values.byName(j['level'] as String),
    headline: Map<String, String>.from(j['headline'] as Map),
    sender: j['sender'] as String,
    sent: DateTime.parse(j['sent'] as String).toUtc(),
    expires: j['expires'] == null
        ? null
        : DateTime.parse(j['expires'] as String).toUtc(),
    areaCodes: List<String>.from(j['areaCodes'] as List? ?? const []),
    // Records stored before this field existed read as false.
    hadPolygons: j['hadPolygons'] == true,
    missingSince: j['missingSince'] == null
        ? null
        : DateTime.parse(j['missingSince'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level.name,
    'headline': headline,
    'sender': sender,
    'sent': sent.toUtc().toIso8601String(),
    'expires': expires?.toUtc().toIso8601String(),
    'areaCodes': areaCodes,
    'hadPolygons': hadPolygons,
    if (missingSince != null)
      'missingSince': missingSince!.toUtc().toIso8601String(),
  };

  // For the detail screen; polygons are not kept, so the area shows province codes only.
  OfficialAlert toAlert() => OfficialAlert(
    id: id,
    sender: sender,
    status: 'Actual',
    msgType: 'Alert',
    level: level,
    headline: headline,
    sent: sent,
    expires: expires,
    areaCodes: areaCodes,
  );
}

// A notice that was shown and then ended, with when we learned it and why.
class HistoryEntry {
  const HistoryEntry({
    required this.record,
    required this.endedAt,
    required this.reason,
  });

  final AlertRecord record;
  final DateTime endedAt;
  final EndReason reason;

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    record: AlertRecord.fromJson(j['record'] as Map<String, dynamic>),
    endedAt: DateTime.parse(j['endedAt'] as String).toUtc(),
    reason: EndReason.values.byName(j['reason'] as String),
  );

  Map<String, dynamic> toJson() => {
    'record': record.toJson(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'reason': reason.name,
  };
}
