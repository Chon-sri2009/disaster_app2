import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_history_entry.dart';
import '../models/official_alert.dart';
import '../services/alert_service.dart';
import '../services/province_locator.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
import '../widgets/warning_banner.dart';

// One official notice in full: what it says, who issued it, when, until when and where. Official
// text is shown as received, in both languages when the agency gave both, never translated.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({
    super.key,
    required this.alert,
    required this.alerts,
    this.provinces,
    this.ended,
  });

  final OfficialAlert alert;
  final AlertService alerts;
  // Null until the boundary file is loaded (or if it fails): codes then show as they came.
  final ProvinceBoundaries? provinces;
  // Set when opened from history: the record is a past notice, so the live-snapshot parts
  // (stale banner, "Received by the app") are hidden and an Ended banner shows instead.
  final HistoryEntry? ended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final style = t.styleFor(alert.level);
    final thai = context.isThai;
    final own = alert.headline[thai ? 'th' : 'en'];
    final other = alert.headline[thai ? 'en' : 'th'];
    final headline = own ?? other ?? context.levelLabel(alert.level);
    // The second block only exists when both languages do; a fallback is not repeated.
    final second = own != null ? other : null;
    final at = alerts.fetchedAt;
    final ended = this.ended;

    final String expiry;
    if (alert.hasExpiry) {
      expiry = context.stamp(alert.effectiveExpiry);
    } else {
      expiry = context.tr(
        // DRAFT wording, owner to approve.
        th:
            'ไม่ระบุเวลาหมดอายุ (แสดง 6 ชั่วโมง) '
            'สิ้นสุดที่ ${context.stamp(alert.effectiveExpiry)}',
        en:
            'No expiry given (shown for 6 hours). '
            'Ends ${context.stamp(alert.effectiveExpiry)}',
      );
    }

    final List<String> areaLines;
    if (alert.areaCodes.isNotEmpty) {
      areaLines = [
        for (final code in alert.areaCodes)
          switch (provinces?.byCode(code)) {
            final p? => '${p.nameTh} · ${p.nameEn}',
            null => code,
          },
      ];
    } else if (alert.polygons.isEmpty && (ended?.record.hadPolygons ?? false)) {
      areaLines = [
        // DRAFT wording, owner to approve.
        context.tr(
          th: 'พื้นที่ระบุเป็นรูปบนแผนที่ (ไม่ได้เก็บไว้ในประวัติ)',
          en: 'Area was given as a map shape (not kept in history)',
        ),
      ];
    } else if (alert.polygons.isNotEmpty) {
      areaLines = [
        // DRAFT wording, owner to approve.
        context.tr(th: 'พื้นที่แสดงบนแผนที่', en: 'Area shown on the map'),
      ];
    } else {
      areaLines = [
        // DRAFT wording, owner to approve.
        context.tr(th: 'ไม่ระบุพื้นที่', en: 'Area not given'),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          // DRAFT wording, owner to approve.
          context.tr(th: 'รายละเอียดประกาศ', en: 'Notice details'),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              AppSpace.lg,
            ),
            children: [
              if (ended != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: WarningBanner(
                    // Icon and word, never colour alone. DRAFT wording, owner to approve.
                    message: context.tr(
                      th:
                          'สิ้นสุดแล้ว: ${endReasonWord(context, ended.reason)} · '
                          '${context.stamp(ended.endedAt)}',
                      en:
                          'Ended: ${endReasonWord(context, ended.reason)} · '
                          '${context.stamp(ended.endedAt)}',
                    ),
                  ),
                )
              else if (alerts.isStale && at != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: WarningBanner(
                    kind: BannerKind.offline,
                    // Same wording as the Home notices card.
                    message: context.tr(
                      th:
                          'อัปเดตประกาศล่าสุด ${context.stamp(at)} '
                          'ข้อมูลอาจไม่เป็นปัจจุบัน',
                      en:
                          'Alerts last updated ${context.stamp(at)}. '
                          'They may be out of date.',
                    ),
                  ),
                ),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusPill(
                        context.levelLabel(alert.level),
                        icon: style.icon,
                        color: style.color,
                        onColor: style.onColor,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(headline, style: theme.textTheme.titleLarge),
                    if (second != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(second, style: theme.textTheme.bodyLarge),
                    ],
                  ],
                ),
              ),
              SectionLabel(
                // DRAFT wording, owner to approve.
                context.tr(th: 'รายละเอียด', en: 'Details'),
              ),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Fact(
                      label: context.tr(
                        th: 'ผู้ออกประกาศ',
                        en: 'Issued by',
                      ), // DRAFT wording, owner to approve.
                      lines: [alert.sender],
                    ),
                    _Fact(
                      label: context.tr(
                        th: 'ออกประกาศเมื่อ',
                        en: 'Issued',
                      ), // DRAFT wording, owner to approve.
                      lines: [context.stamp(alert.sent)],
                    ),
                    _Fact(
                      label: context.tr(
                        th: 'หมดอายุ',
                        en: 'Expires',
                      ), // DRAFT wording, owner to approve.
                      lines: [expiry],
                    ),
                    _Fact(
                      label: context.tr(
                        th: 'พื้นที่ที่เกี่ยวข้อง',
                        en: 'Affected area',
                      ), // DRAFT wording, owner to approve.
                      lines: areaLines,
                      last: ended != null,
                    ),
                    if (ended == null)
                      _Fact(
                        label: context.tr(
                          th: 'แอปได้รับข้อมูลเมื่อ',
                          en: 'Received by the app',
                        ), // DRAFT wording, owner to approve.
                        lines: [
                          at == null
                              // DRAFT wording, owner to approve.
                              ? context.tr(th: 'ไม่มีข้อมูล', en: 'No data')
                              : context.stamp(at),
                          // DRAFT wording, owner to approve.
                          context.tr(
                            th: 'คือเวลาที่ข้อมูลชุดนี้ถูกสร้างบนเซิร์ฟเวอร์',
                            en: 'This is when the data was built on the server.',
                          ),
                        ],
                        last: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                // DRAFT wording, owner to approve.
                context.tr(
                  th:
                      'นี่คือประกาศจากหน่วยงานทางการ แสดงตามที่ได้รับ '
                      'ไม่ใช่คำสั่งจากแอปนี้',
                  en:
                      'This is an official source\'s notice, shown as received. '
                      'It is not an order from this app.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: t.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Why a notice ended, in one word. Shared by the history list and the detail screen.
String endReasonWord(BuildContext context, EndReason r) => switch (r) {
  // DRAFT wording, owner to approve.
  EndReason.expired => context.tr(th: 'หมดอายุ', en: 'Expired'),
  EndReason.cancelled => context.tr(th: 'ยกเลิก', en: 'Cancelled'),
  EndReason.replaced => context.tr(th: 'ถูกแทนที่', en: 'Replaced'),
};

// A small label over one or more value lines.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.lines, this.last = false});

  final String label;
  final List<String> lines;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.tokens.inkMuted,
            ),
          ),
          for (final line in lines)
            Text(line, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
