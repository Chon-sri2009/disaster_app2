import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_history_entry.dart';
import '../models/alert_level.dart';
import '../models/official_alert.dart';
import '../services/alert_service.dart';
import '../services/province_locator.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
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

  // What this screen shows follows the service (R-F9): the notice may expire, be cancelled
  // or replaced, and the data may go stale while the screen stays open. Opened from history,
  // the given record stands. Otherwise: a history entry for this notice wins; then the
  // service's own clock (expiry is proven by time alone, even before the next download);
  // otherwise the notice is still live.
  HistoryEntry? _currentEnded() {
    final given = ended;
    if (given != null) return given;
    if (alerts.visibleAlerts.any((a) => a.id == alert.id)) return null;
    for (final e in alerts.history) {
      if (e.record.id == alert.id) return e;
    }
    final expiry = alert.effectiveExpiry;
    if (!alerts.now.toUtc().isBefore(expiry)) {
      return HistoryEntry(
        record: AlertRecord.of(alert),
        endedAt: expiry,
        reason: EndReason.expired,
      );
    }
    return null;
  }

  // The live update that replaced this notice (R-F10 c): the visible alert whose references
  // contain this id; the loudest if several. Null when the notice did not end as replaced,
  // when opened from history (the record stands alone), or when no replacement is live now.
  OfficialAlert? _replacement(HistoryEntry? ended) {
    if (this.ended != null) return null;
    if (ended == null || ended.reason != EndReason.replaced) return null;
    OfficialAlert? best;
    for (final a in alerts.visibleAlerts) {
      if (!a.references.contains(alert.id)) continue;
      if (best == null || a.level.index > best.level.index) best = a;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: alerts, builder: _content);

  Widget _content(BuildContext context, Widget? _) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final thai = context.isThai;
    final own = alert.headline[thai ? 'th' : 'en'];
    final other = alert.headline[thai ? 'en' : 'th'];
    final headline = own ?? other ?? context.levelLabel(alert.level);
    // The second block only exists when both languages do; a fallback is not repeated.
    final second = own != null ? other : null;
    final at = alerts.fetchedAt;
    final ended = _currentEnded();
    final replacement = _replacement(ended);

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
      // Back arrow only: the title lives in the body, where it wraps instead of being cut.
      appBar: AppBar(),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              AppSpace.lg,
            ),
            children: [
              ScreenTitle(
                // DRAFT wording, owner to approve.
                context.tr(th: 'รายละเอียดประกาศ', en: 'Notice details'),
                compact: true,
              ),
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
                ),
              if (replacement != null)
                _ReplacementRow(
                  replacement: replacement,
                  alerts: alerts,
                  provinces: provinces,
                ),
              // Opened from history the record stands alone; otherwise Ended came from the
              // service's clock, which may be wrong, so the out-of-date caveat shows with it.
              if (this.ended == null && alerts.isStale && at != null)
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
              // Severity first: the tier of this notice, then what it says.
              _TierBlock(
                label: context.levelLabel(alert.level),
                level: alert.level,
                ended: ended != null,
              ),
              const SizedBox(height: AppSpace.md),
              Text(headline, style: theme.textTheme.titleLarge),
              if (second != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(second, style: theme.textTheme.bodyLarge),
              ],
              Section(
                // DRAFT wording, owner to approve.
                title: context.tr(th: 'รายละเอียด', en: 'Details'),
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
                    ),
                ],
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

// The update that replaced this notice, above the quiet tier block so a live DANGER update is
// not missed. It shows the update's own tier and headline and says nothing more about levels.
class _ReplacementRow extends StatelessWidget {
  const _ReplacementRow({
    required this.replacement,
    required this.alerts,
    required this.provinces,
  });

  final OfficialAlert replacement;
  final AlertService alerts;
  final ProvinceBoundaries? provinces;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = replacement;
    final style = t.styleFor(a.level);
    final loud = a.level == AlertLevel.warning || a.level == AlertLevel.danger;
    // Same headline choice as the Home notice rows.
    final headline =
        a.headline[context.isThai ? 'th' : 'en'] ??
        a.headline['th'] ??
        context.levelLabel(a.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Section(
        // Wording approved by the owner 2026-11-23.
        title: context.tr(
          th: 'ถูกแทนที่ด้วยประกาศใหม่',
          en: 'Replaced by a newer notice',
        ),
        children: [
          RuledRow(
            key: const ValueKey('replacement-row'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlertDetailScreen(
                  alert: a,
                  alerts: alerts,
                  provinces: provinces,
                ),
              ),
            ),
            title: headline,
            subtitle: '${a.sender} · ${context.stamp(a.sent)}',
            semanticLabel:
                '${context.levelLabel(a.level)}. $headline. '
                '${a.sender}, ${context.stamp(a.sent)}',
            trailing: Tag(
              context.levelLabel(a.level),
              icon: style.icon,
              color: style.color,
              onColor: loud ? style.onColor : null,
            ),
          ),
        ],
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

// The tier of this notice, on top. WARNING and DANGER fill with the tier colour; quieter tiers sit
// on the ground under a thick tier rule (as on the Home slab). Icon and word always show.
class _TierBlock extends StatelessWidget {
  const _TierBlock({
    required this.label,
    required this.level,
    required this.ended,
  });

  final String label;
  final AlertLevel level;
  // An ended notice is a record, not a live alert: never fill it with the tier colour.
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = t.styleFor(level);
    final loud =
        !ended && (level == AlertLevel.warning || level == AlertLevel.danger);
    final watch = level == AlertLevel.watch;
    return Container(
      key: const ValueKey('tier-block'),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: loud ? style.color : t.ground,
        border: loud
            ? null
            : Border(
                top: BorderSide(color: style.rule, width: AppStroke.slab),
              ),
      ),
      child: Row(
        children: [
          if (watch)
            Container(
              padding: const EdgeInsets.all(AppSpace.xs),
              color: style.color,
              child: Icon(
                style.icon,
                size: AppIconSize.lg,
                color: style.onColor,
              ),
            )
          else
            Icon(
              style.icon,
              size: AppIconSize.lg,
              color: loud ? style.onColor : style.onGround,
            ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: loud ? style.onColor : t.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// A small label over one or more value lines, with a hairline under it.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.lines});

  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.hairline, width: AppStroke.rule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: t.inkMuted),
            ),
            for (final line in lines)
              Text(line, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
