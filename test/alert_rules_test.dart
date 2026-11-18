import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/models/official_alert.dart';
import 'package:disaster_app2/services/alert_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

OfficialAlert alert(
  String id, {
  String status = 'Actual',
  String msgType = 'Alert',
  AlertLevel level = AlertLevel.warning,
  DateTime? expires,
  List<String> references = const [],
  String? poly = '13,100 13,101 14,101 14,100',
  List<String> areaCodes = const [],
}) => OfficialAlert(
  id: id,
  sender: 'TMD',
  status: status,
  msgType: msgType,
  level: level,
  headline: const {'th': 'x'},
  sent: DateTime.utc(2026, 11, 12, 1),
  expires: expires,
  references: references,
  polygons: poly == null ? const [] : [AlertRules.parseCapPolygon(poly)],
  areaCodes: areaCodes,
);

void main() {
  combineTests();
  final now = DateTime.utc(2026, 11, 12, 2);
  final inside = LatLng(13.5, 100.5);

  test('a Test or Exercise Cancel does not hide a live Actual alert', () {
    final all = [
      alert('live'),
      alert('t', status: 'Test', msgType: 'Cancel', references: ['live']),
      alert('e', status: 'Exercise', msgType: 'Update', references: ['live']),
    ];
    expect(AlertRules.visible(all, now).map((a) => a.id), ['live']);
  });

  test('an Actual Cancel hides its target; an Actual Update replaces it', () {
    final cancelled = [
      alert('live'),
      alert('c', msgType: 'Cancel', references: ['live']),
    ];
    expect(AlertRules.visible(cancelled, now), isEmpty);
    final updated = [
      alert('old'),
      alert('new', msgType: 'Update', references: ['old']),
    ];
    expect(AlertRules.visible(updated, now).map((a) => a.id), ['new']);
  });

  test('Test and Exercise alerts never reach users', () {
    final all = [alert('a', status: 'Test'), alert('b', status: 'Exercise')];
    expect(AlertRules.visible(all, now), isEmpty);
  });

  test('expired alerts disappear; missing expiry uses default lifetime', () {
    final expired = alert(
      'a',
      expires: now.subtract(const Duration(minutes: 1)),
    );
    final noExpiry = alert('b');
    expect(AlertRules.visible([expired], now), isEmpty);
    expect(AlertRules.visible([noExpiry], now), hasLength(1));
    expect(noExpiry.hasExpiry, isFalse);
    expect(
      AlertRules.visible([noExpiry], now.add(const Duration(hours: 6))),
      isEmpty,
    );
  });

  test('Update replaces and Cancel removes the referenced alert', () {
    final base = alert('a');
    final cancel = alert('c', msgType: 'Cancel', references: ['a']);
    expect(AlertRules.visible([base, cancel], now), isEmpty);
    final update = alert('u', msgType: 'Update', references: ['a']);
    expect(AlertRules.visible([base, update], now).map((a) => a.id), ['u']);
  });

  test('level is the highest inside the polygon, safe outside', () {
    final all = [
      alert('w', level: AlertLevel.watch),
      alert('d', level: AlertLevel.danger),
    ];
    expect(AlertRules.levelAt(all, inside, now), AlertLevel.danger);
    expect(AlertRules.levelAt(all, LatLng(15, 100.5), now), AlertLevel.safe);
  });

  test('CAP polygon axis order is lat,lon', () {
    final ring = AlertRules.parseCapPolygon('13,100 13,101 14,101 14,100');
    expect(ring.first.latitude, 13);
    expect(ring.first.longitude, 100);
    expect(AlertRules.contains(ring, LatLng(100.5, 13.5)), isFalse);
  });

  test('polygon straddling 102E is handled', () {
    final ring = AlertRules.parseCapPolygon(
      '13,101.5 13,102.5 14,102.5 14,101.5',
    );
    expect(AlertRules.contains(ring, LatLng(13.5, 102.0)), isTrue);
    expect(AlertRules.contains(ring, LatLng(13.5, 102.6)), isFalse);
  });

  test('JSON snapshot uses [lon, lat] rings', () {
    final a = OfficialAlert.fromJson({
      'id': 'x',
      'sender': 'TMD',
      'status': 'Actual',
      'msgType': 'Alert',
      'level': 'warning',
      'headline': {'th': 'ฝนตกหนัก'},
      'sent': '2026-11-12T01:00:00Z',
      'polygons': [
        [
          [100.0, 13.0],
          [101.0, 13.0],
          [101.0, 14.0],
          [100.0, 14.0],
        ],
      ],
    });
    expect(a.polygons.first.first, LatLng(13, 100));
    // Snapshots and caches from before Task 7 have no areaCodes.
    expect(a.areaCodes, isEmpty);
  });

  test('JSON snapshot areaCodes are read', () {
    final a = OfficialAlert.fromJson({
      'id': 'x',
      'sender': 'TMD',
      'status': 'Actual',
      'msgType': 'Alert',
      'level': 'warning',
      'headline': {'th': 'x'},
      'sent': '2026-11-12T01:00:00Z',
      'areaCodes': ['TH-10', 'TH-83'],
      'polygons': [],
    });
    expect(a.areaCodes, ['TH-10', 'TH-83']);
  });

  group('province matching', () {
    final far = LatLng(7.9, 98.4); // outside the default test polygon
    final geoOnly = alert('g', poly: null, areaCodes: ['TH-83', 'TH-99']);

    test('a geocode-only alert escalates only in a listed province', () {
      expect(
        AlertRules.levelAt([geoOnly], far, now, provinceCode: 'TH-83'),
        AlertLevel.warning,
      );
      expect(
        AlertRules.levelAt([geoOnly], far, now, provinceCode: 'TH-10'),
        AlertLevel.safe,
      );
      // No known province (no GPS, at sea, bundle failed): never matches by code.
      expect(AlertRules.levelAt([geoOnly], far, now), AlertLevel.safe);
      expect(AlertRules.matches(geoOnly, far, null), isFalse);
    });

    test('a code unknown to the bundle matches only that exact code', () {
      expect(AlertRules.matches(geoOnly, far, 'TH-99'), isTrue);
      expect(AlertRules.matches(geoOnly, far, 'TH-98'), isFalse);
    });

    test('an alert with polygons ignores its areaCodes', () {
      final both = alert('b', areaCodes: ['TH-83']);
      expect(AlertRules.matches(both, far, 'TH-83'), isFalse);
      expect(
        AlertRules.levelAt([both], far, now, provinceCode: 'TH-83'),
        AlertLevel.safe,
      );
      expect(AlertRules.matches(both, inside, null), isTrue);
      expect(AlertRules.matches(both, inside, 'TH-10'), isTrue);
    });

    test('an alert with neither polygons nor codes matches nothing', () {
      final none = alert('n', poly: null);
      expect(AlertRules.matches(none, inside, 'TH-10'), isFalse);
    });

    test('a hidden geocode-only alert does not escalate', () {
      final expired = alert(
        'e',
        poly: null,
        areaCodes: ['TH-83'],
        expires: now.subtract(const Duration(minutes: 1)),
      );
      expect(
        AlertRules.levelAt([expired], far, now, provinceCode: 'TH-83'),
        AlertLevel.safe,
      );
    });
  });
}

void combineTests() {
  group('AlertRules.combine', () {
    test('an official alert escalates a missing or lower sensor level', () {
      expect(AlertRules.combine(null, AlertLevel.danger), AlertLevel.danger);
      expect(
        AlertRules.combine(AlertLevel.safe, AlertLevel.watch),
        AlertLevel.watch,
      );
    });
    test('official "no alert here" never creates or lowers a level', () {
      expect(AlertRules.combine(null, AlertLevel.safe), isNull);
      expect(
        AlertRules.combine(AlertLevel.danger, AlertLevel.safe),
        AlertLevel.danger,
      );
      expect(AlertRules.combine(AlertLevel.warning, null), AlertLevel.warning);
    });
    test('the worse level wins', () {
      expect(
        AlertRules.combine(AlertLevel.danger, AlertLevel.watch),
        AlertLevel.danger,
      );
    });
  });
}
