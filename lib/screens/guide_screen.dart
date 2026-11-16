import 'package:flutter/material.dart';

import '../data/guide_data.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import 'about_screen.dart';

// Guide screen: offline first-aid and evacuation topics in an expandable list.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return SafeArea(
      child: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            Text('Offline guide', style: theme.textTheme.headlineMedium),
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
                      topic.title,
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
                      for (var i = 0; i < topic.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: Text(
                            '${i + 1}. ${topic.steps[i]}',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ListTile(
              leading: Icon(Icons.info_outline, color: t.accent),
              title: const Text('About and disclaimer'),
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
