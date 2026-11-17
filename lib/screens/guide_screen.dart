import 'package:flutter/material.dart';

import '../data/emergency_numbers.dart';
import '../data/guide_data.dart';
import '../l10n/l10n.dart';
import '../models/guide_topic.dart';
import '../services/emergency_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
import 'settings_screen.dart';

// Guide: two folding cards, urgent first aid on top and disaster topics below, each topic a row
// with a colored accent bar. Each topic opens as its own page.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.storage});

  final StorageService storage;

  void _open(BuildContext context, GuideTopic topic) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => GuideTopicScreen(topic: topic)),
  );

  @override
  Widget build(BuildContext context) {
    final thai = context.isThai;
    final firstAid = GuideData.topics
        .where((t) => t.kind == GuideKind.firstAid)
        .toList();
    final disaster = GuideData.topics
        .where((t) => t.kind == GuideKind.disaster)
        .toList();
    final t = context.tokens;
    Widget row(GuideTopic topic, Color accent) => AccentRow(
      accent: accent,
      leading: Container(
        width: AppSize.tapTarget,
        height: AppSize.tapTarget,
        decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
        child: Icon(topic.icon, color: t.brand),
      ),
      title: thai ? topic.titleTh : topic.title,
      trailing: Icon(Icons.chevron_right, color: t.inkMuted),
      onTap: () => _open(context, topic),
    );
    // The header band paints behind the status bar, so the top is not inset.
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandHeader(
            title: context.tr(th: 'คู่มือออฟไลน์', en: 'Offline guide'),
            trailing: SettingsButton(storage: storage),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CollapsibleCard(
                        title: context.tr(
                          th: 'ปฐมพยาบาลด่วน (${firstAid.length})',
                          en: 'Urgent first aid (${firstAid.length})',
                        ),
                        children: [
                          for (final topic in firstAid)
                            row(topic, t.tier(AlertTier.danger).color),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      CollapsibleCard(
                        title: context.tr(
                          th: 'น้ำท่วมและแผ่นดินไหว (${disaster.length})',
                          en: 'Floods and earthquakes (${disaster.length})',
                        ),
                        children: [
                          for (final topic in disaster) row(topic, t.brand),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// One topic as a page: large numbered steps, and a call button on first-aid pages.
class GuideTopicScreen extends StatelessWidget {
  const GuideTopicScreen({super.key, required this.topic});

  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final thai = context.isThai;
    final steps = thai ? topic.stepsTh : topic.steps;
    final medical = EmergencyNumbers.medical;
    return Scaffold(
      appBar: AppBar(title: Text(thai ? topic.titleTh : topic.title)),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              SoftCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.md,
                  0,
                ),
                child: Column(
                  children: [
                    for (final (i, step) in steps.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: AppIconSize.xl - AppSpace.sm,
                              height: AppIconSize.xl - AppSpace.sm,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.brandSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: t.brand,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Text(
                                step,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (topic.kind == GuideKind.firstAid) ...[
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.danger,
                    foregroundColor: t.onDanger,
                  ),
                  onPressed: () => EmergencyLauncher.call(medical.number),
                  icon: const Icon(Icons.call),
                  label: Text(
                    context.tr(
                      th: 'โทร ${medical.number} ${context.serviceName(medical)}',
                      en: 'Call ${medical.number} ${context.serviceName(medical)}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
