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

// Guide: offline first aid on top as large tiles (the urgent shelf), disaster topics below as
// rows. Each topic opens as its own page.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.storage});

  final StorageService storage;

  void _open(BuildContext context, GuideTopic topic) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => GuideTopicScreen(topic: topic)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thai = context.isThai;
    final firstAid = GuideData.topics
        .where((t) => t.kind == GuideKind.firstAid)
        .toList();
    final disaster = GuideData.topics
        .where((t) => t.kind == GuideKind.disaster)
        .toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandHeader(
            title: context.tr(th: 'คู่มือออฟไลน์', en: 'Offline guide'),
            trailing: SettingsButton(storage: storage),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.lg,
              ),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionLabel(
                        context.tr(th: 'ปฐมพยาบาลด่วน', en: 'Urgent first aid'),
                      ),
                      for (var i = 0; i < firstAid.length; i += 2) ...[
                        if (i > 0) const SizedBox(height: AppSpace.sm),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final topic in firstAid.skip(i).take(2)) ...[
                                if (topic != firstAid[i])
                                  const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: SoftTile(
                                    onTap: () => _open(context, topic),
                                    padding: const EdgeInsets.all(AppSpace.sm),
                                    child: Row(
                                      children: [
                                        Icon(topic.icon, size: AppIconSize.lg),
                                        const SizedBox(width: AppSpace.sm),
                                        Expanded(
                                          child: Text(
                                            thai ? topic.titleTh : topic.title,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      SectionLabel(
                        context.tr(
                          th: 'น้ำท่วมและแผ่นดินไหว',
                          en: 'Floods and earthquakes',
                        ),
                      ),
                      for (final topic in disaster)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: SoftTile(
                            onTap: () => _open(context, topic),
                            child: Row(
                              children: [
                                Icon(topic.icon),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Text(
                                    thai ? topic.titleTh : topic.title,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
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
              for (final (i, step) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: AppIconSize.lg,
                        height: AppIconSize.lg,
                        alignment: Alignment.center,
                        color: t.ink,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: t.ground,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(step, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              if (topic.kind == GuideKind.firstAid) ...[
                const SizedBox(height: AppSpace.sm),
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
