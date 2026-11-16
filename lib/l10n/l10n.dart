import 'package:flutter/widgets.dart';

import '../data/emergency_numbers.dart';
import '../models/alert_level.dart';
import '../services/location_service.dart';

// Thai/English text lives next to where it is used: context.tr(th: ..., en: ...).
// The helpers below cover the strings that several screens share.
extension AppL10n on BuildContext {
  bool get isThai => Localizations.localeOf(this).languageCode == 'th';

  String tr({required String th, required String en}) => isThai ? th : en;

  String get cmUnit => tr(th: 'ซม.', en: 'cm');

  String levelLabel(AlertLevel level) => switch (level) {
    AlertLevel.safe => tr(th: 'ปลอดภัย', en: 'Safe'),
    AlertLevel.watch => tr(th: 'เฝ้าระวัง', en: 'Watch'),
    AlertLevel.warning => tr(th: 'เตือนภัย', en: 'Warning'),
    AlertLevel.danger => tr(th: 'อันตราย', en: 'Danger'),
  };

  String levelAdvice(AlertLevel level) => switch (level) {
    AlertLevel.safe => tr(
      th: 'ยังไม่ต้องทำอะไร',
      en: 'Nothing to do right now.',
    ),
    AlertLevel.watch => tr(
      th: 'ติดตามข่าวและเตรียมพร้อมออกจากพื้นที่',
      en: 'Stay alert and be ready to move.',
    ),
    AlertLevel.warning => tr(
      th: 'เตรียมอพยพ และทำตามคำสั่งของเจ้าหน้าที่',
      en: 'Get ready to leave and follow official instructions.',
    ),
    AlertLevel.danger => tr(
      th: 'อพยพไปศูนย์พักพิงทันที',
      en: 'Leave for a shelter now.',
    ),
  };

  String serviceName(EmergencyNumber n) => tr(th: n.serviceTh, en: n.service);

  String locationError(LocationIssue issue) => switch (issue) {
    LocationIssue.serviceOff => tr(
      th: 'ยังไม่ได้เปิด GPS กรุณาเปิดตำแหน่งในโทรศัพท์',
      en: 'Location is turned off. Please turn on GPS.',
    ),
    LocationIssue.denied => tr(
      th: 'แอปยังไม่ได้รับอนุญาตให้ใช้ตำแหน่ง',
      en: 'Location permission was denied.',
    ),
    LocationIssue.blocked => tr(
      th: 'การใช้ตำแหน่งถูกบล็อกไว้ เปิดได้ในการตั้งค่าโทรศัพท์',
      en: 'Location permission is blocked. Enable it in the phone settings.',
    ),
    LocationIssue.timeout => tr(
      th: 'GPS ตอบช้าเกินไป ลองอีกครั้งในที่โล่งหรือใกล้หน้าต่าง',
      en: 'GPS took too long to answer. Try again outside or near a window.',
    ),
    LocationIssue.unknown => tr(
      th: 'อ่านตำแหน่ง GPS จากเครื่องนี้ไม่ได้',
      en: 'Could not read the GPS position on this device.',
    ),
  };

  // 14:03:22, for readings that tick every few seconds.
  String clock(DateTime t) {
    final l = t.toLocal();
    return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
  }

  // "Today 14:03", "Yesterday 09:10", or "16 Nov 14:03" (Buddhist-era year if not this year).
  String stamp(DateTime t, {DateTime? now}) {
    final l = t.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final time = '${_two(l.hour)}:${_two(l.minute)}';
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(l.year, l.month, l.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return tr(th: 'วันนี้ $time', en: 'Today $time');
    if (diff == 1) return tr(th: 'เมื่อวาน $time', en: 'Yesterday $time');
    final month = isThai ? _monthsTh[l.month - 1] : _monthsEn[l.month - 1];
    final year = l.year == n.year ? '' : ' ${isThai ? l.year + 543 : l.year}';
    return '${l.day} $month$year $time';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static const _monthsTh = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
