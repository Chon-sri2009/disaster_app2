import 'package:flutter/material.dart';

import '../data/emergency_numbers.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';

// About: disclaimer (content required by DEVELOPMENT_PLAN.md 9.4) and data sources (9.2, 5.7).
// DRAFT wording: the owner must rewrite it and Thai counsel must review it before release.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disclaimer = [
      context.tr(
        th: 'แอปนี้ไม่ใช่ช่องทางแจ้งเตือนภัยอย่างเป็นทางการของรัฐ',
        en: 'This app is not an official government warning channel.',
      ),
      context.tr(
        th:
            'การเตือนภัยอย่างเป็นทางการมาจาก Cell Broadcast (T-Alert), กรมป้องกันและบรรเทาสาธารณภัย (ปภ.), '
            'ศูนย์เตือนภัยพิบัติแห่งชาติ (NDWC) และกรมอุตุนิยมวิทยา (TMD) '
            'กรุณาทำตามประกาศเหล่านั้นและคำแนะนำของเจ้าหน้าที่ก่อน',
        en:
            'Official warnings come from Cell Broadcast (T-Alert), DDPM, NDWC and TMD. '
            'Follow them and local officials first.',
      ),
      context.tr(
        th:
            'ข้อมูลในแอปอาจล่าช้า ไม่ครบ หรือคลาดเคลื่อน '
            'การไม่มีการแจ้งเตือนไม่ได้แปลว่าปลอดภัย',
        en: 'Alerts here may be late, incomplete or wrong. No alert does not mean no danger.',
      ),
      context.tr(
        th: 'เซนเซอร์ชุมชนไม่ใช่เครื่องวัดอย่างเป็นทางการ',
        en: 'Community sensors are not official gauges.',
      ),
    ];
    final sources = [
      (
        context.tr(
          th: 'กรมอุตุนิยมวิทยา (TMD)',
          en: 'Thai Meteorological Department (TMD)',
        ),
        context.tr(
          th: 'ประกาศเตือนภัยแบบ CAP เป็นสาธารณสมบัติตามที่ฟีดระบุ',
          en: 'CAP alerts, public domain per the feed',
        ),
      ),
      (
        'OpenStreetMap contributors',
        context.tr(
          th: 'แผนที่ © ผู้ร่วมสร้าง OpenStreetMap',
          en: 'Map tiles, © OpenStreetMap contributors',
        ),
      ),
      (
        'OCHA / Royal Thai Survey Department',
        context.tr(
          th: 'ขอบเขตการปกครอง CC BY-IGO',
          en: 'Admin boundaries, CC BY-IGO',
        ),
      ),
      (
        context.tr(
          th: 'ข้อมูลเซนเซอร์และประกาศในเวอร์ชันนี้',
          en: 'Sensor and alert data in this build',
        ),
        context.tr(
          th: 'เป็นข้อมูลทดลอง ไม่ใช่ค่าจริง',
          en: 'Mock data, not live readings',
        ),
      ),
    ];
    final numbers = EmergencyNumbers.sos
        .map((n) => '${n.number} (${context.serviceName(n)})')
        .join(', ');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            th: 'เกี่ยวกับแอปและข้อสงวนสิทธิ์',
            en: 'About and disclaimer',
          ),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              0,
              AppSpace.md,
              AppSpace.lg,
            ),
            children: [
              SectionLabel(context.tr(th: 'ข้อสงวนสิทธิ์', en: 'Disclaimer')),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in disclaimer)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: Text(line, style: theme.textTheme.bodyLarge),
                      ),
                    Text(
                      context.tr(
                        th: 'ในเหตุฉุกเฉิน โทร $numbers',
                        en: 'In an emergency call $numbers.',
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              SectionLabel(context.tr(th: 'แหล่งข้อมูล', en: 'Data sources')),
              for (final s in sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1, style: theme.textTheme.titleSmall),
                        Text(s.$2, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
