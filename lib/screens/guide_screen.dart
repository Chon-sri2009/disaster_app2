import 'package:flutter/material.dart';

import '../data/guide_data.dart';
import '../l10n/app_lang.dart';
import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import 'about_screen.dart';

// Guide screen: offline first-aid and evacuation topics in an expandable list, plus the language switch.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final thai = context.isThai;
    return SafeArea(
      child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(th: 'คู่มือออฟไลน์', en: 'Offline guide'),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                // Shows the language you would switch to, written in that language.
                TextButton.icon(
                  onPressed: () =>
                      storage.setLanguage(thai ? AppLang.en : AppLang.th),
                  icon: const Icon(Icons.translate),
                  label: Text(thai ? 'English' : 'ภาษาไทย'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            for (final topic in GuideData.topics)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    // 200 ms, or instant when the phone's "remove animations" setting is on.
                    expansionAnimationStyle: AnimationStyle(
                      duration: context.motion(AppMotion.base),
                      curve: Curves.easeOut,
                    ),
                    leading: Icon(topic.icon, color: t.accent),
                    title: Text(
                      thai ? topic.titleTh : topic.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      0,
                      AppSpace.md,
                      AppSpace.md,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var i = 0;
                        i < (thai ? topic.stepsTh : topic.steps).length;
                        i++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: Text(
                            '${i + 1}. ${(thai ? topic.stepsTh : topic.steps)[i]}',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ListTile(
              leading: Icon(Icons.info_outline, color: t.accent),
              title: Text(
                context.tr(
                  th: 'เกี่ยวกับแอปและข้อสงวนสิทธิ์',
                  en: 'About and disclaimer',
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
