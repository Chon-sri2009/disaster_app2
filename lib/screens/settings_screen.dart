import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice.dart';
import 'about_screen.dart';

// The gear in every tab's header: opens Settings.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr(th: 'ตั้งค่า', en: 'Settings'),
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(storage: storage),
        ),
      ),
    );
  }
}

// Settings: the app language and the About page.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr(th: 'ตั้งค่า', en: 'Settings')),
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
                SectionLabel(context.tr(th: 'ภาษา', en: 'Language')),
                // Each option is written in its own language, so either reader can find it.
                SegmentedButton<AppLang>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: AppLang.th, label: Text('ภาษาไทย')),
                    ButtonSegment(value: AppLang.en, label: Text('English')),
                  ],
                  selected: {storage.language},
                  onSelectionChanged: (s) => storage.setLanguage(s.first),
                ),
                SectionLabel(context.tr(th: 'เกี่ยวกับ', en: 'About')),
                NoticeTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          context.tr(
                            th: 'เกี่ยวกับแอปและข้อสงวนสิทธิ์',
                            en: 'About and disclaimer',
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
