import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_history_entry.dart';
import '../services/alert_service.dart';
import '../services/province_locator.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
import 'alert_detail_screen.dart';

// Notices that were shown and have ended. A record only: it never changes any level on Home.
class AlertHistoryScreen extends StatelessWidget {
  const AlertHistoryScreen({super.key, required this.alerts, this.provinces});

  final AlertService alerts;
  final ProvinceBoundaries? provinces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          // DRAFT wording, owner to approve.
          context.tr(th: 'ประวัติประกาศ', en: 'Alert history'),
        ),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListenableBuilder(
            listenable: alerts,
            builder: (context, _) {
              final entries = alerts.history;
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Text(
                    // DRAFT wording, owner to approve. Says nothing about safety.
                    context.tr(
                      th: 'ยังไม่มีประกาศที่สิ้นสุดแล้ว',
                      en: 'No ended alerts yet',
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpace.md),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, e) in entries.indexed) ...[
                          if (i > 0) const Divider(),
                          _Row(
                            entry: e,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AlertDetailScreen(
                                  alert: e.record.toAlert(),
                                  alerts: alerts,
                                  provinces: provinces,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    // DRAFT wording, owner to approve.
                    context.tr(
                      th: 'บันทึกเก็บไว้ 30 วัน ไม่ใช่สถานะปัจจุบัน',
                      en: 'Kept for 30 days. This is not the current status.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: t.inkMuted,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _reasonWord(BuildContext context, EndReason r) => switch (r) {
  // DRAFT wording, owner to approve.
  EndReason.expired => context.tr(th: 'หมดอายุ', en: 'Expired'),
  EndReason.cancelled => context.tr(th: 'ยกเลิก', en: 'Cancelled'),
  EndReason.replaced => context.tr(th: 'ถูกแทนที่', en: 'Replaced'),
};

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = entry.record;
    final style = context.tokens.styleFor(r.level);
    final headline =
        r.headline[context.isThai ? 'th' : 'en'] ??
        r.headline['th'] ??
        r.headline['en'] ??
        context.levelLabel(r.level);
    final reason = _reasonWord(context, entry.reason);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccentRow(
          // Opens the full notice (min 48 dp tall, set by AccentRow).
          onTap: onTap,
          accent: style.color,
          title: headline,
          subtitle: '${r.sender} · $reason ${context.stamp(entry.endedAt)}',
          trailing: StatusPill(
            context.levelLabel(r.level),
            icon: style.icon,
            color: style.color,
            onColor: style.onColor,
          ),
        ),
      ],
    );
  }
}
