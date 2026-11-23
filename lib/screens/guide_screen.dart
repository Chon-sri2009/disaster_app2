import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/emergency_numbers.dart';
import '../data/guide_data.dart';
import '../l10n/l10n.dart';
import '../models/guide_topic.dart';
import '../services/emergency_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
import 'settings_screen.dart';

// Guide: a ruled index in two groups, urgent first aid (thick danger rule) and disaster topics
// (ink rule), each topic a row. Both groups are always open: with eight topics there is little to
// fold, and a folded urgent group is one more tap in an emergency. Each topic opens as its own page.
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
    Widget row(GuideTopic topic) => RuledRow(
      icon: topic.icon,
      title: thai ? topic.titleTh : topic.title,
      trailing: Icon(Icons.chevron_right, color: t.inkMuted),
      onTap: () => _open(context, topic),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      // The title sits on the ground, so the status bar is inset; the nav bar is the Scaffold's.
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            0,
            AppSpace.md,
            AppSpace.lg,
          ),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(
                  context.tr(th: 'คู่มือออฟไลน์', en: 'Offline guide'),
                  trailing: SettingsButton(storage: storage),
                ),
                Section(
                  title: context.tr(
                    th: 'ปฐมพยาบาลด่วน (${firstAid.length})',
                    en: 'Urgent first aid (${firstAid.length})',
                  ),
                  ruleColor: t.danger,
                  titleColor: t.dangerInk,
                  children: [for (final topic in firstAid) row(topic)],
                ),
                Section(
                  title: context.tr(
                    th: 'น้ำท่วมและแผ่นดินไหว (${disaster.length})',
                    en: 'Floods and earthquakes (${disaster.length})',
                  ),
                  ruleColor: t.ink,
                  children: [for (final topic in disaster) row(topic)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One topic as a page: numbered steps as ruled rows, and a call button on first-aid pages.
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
      // Back arrow only: the title lives in the body, where long Thai wraps instead of being cut.
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.md),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(thai ? topic.titleTh : topic.title, compact: true),
                Container(height: AppStroke.rule, color: t.hairline),
                for (final (i, step) in steps.indexed)
                  RuledRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Plain bold number, same line height as the step so it sits by line one.
                    leading: SizedBox(
                      width: AppIconSize.lg,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    title: step,
                    titleStyle: theme.textTheme.bodyLarge,
                  ),
                if (topic.kind == GuideKind.firstAid) ...[
                  const SizedBox(height: AppSpace.md),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: t.onDanger,
                      minimumSize: const Size.fromHeight(AppSize.primaryButton),
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
      ),
    );
  }
}
