import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
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

// Settings: the app language, day or night board, and the About page.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr(th: 'ตั้งค่า', en: 'Settings')),
        ),
        body: SafeArea(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionLabel(
                        context.tr(th: 'ภาษา', en: 'Language'),
                        inCard: true,
                      ),
                      // Each option is written in its own language, so either reader can find it.
                      SegmentedButton<AppLang>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: AppLang.th,
                            label: Text('ภาษาไทย'),
                          ),
                          ButtonSegment(
                            value: AppLang.en,
                            label: Text('English'),
                          ),
                        ],
                        selected: {storage.language},
                        onSelectionChanged: (s) => storage.setLanguage(s.first),
                      ),
                      const SizedBox(height: AppSpace.md),
                      SectionLabel(
                        context.tr(th: 'ธีม', en: 'Theme'),
                        inCard: true,
                      ),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto),
                            label: Text(
                              context.tr(th: 'ตามเครื่อง', en: 'Phone'),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode),
                            label: Text(context.tr(th: 'สว่าง', en: 'Light')),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode),
                            label: Text(context.tr(th: 'มืด', en: 'Dark')),
                          ),
                        ],
                        selected: {storage.themeMode},
                        onSelectionChanged: (s) =>
                            storage.setThemeMode(s.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.xs,
                  ),
                  child: AccentRow(
                    accent: t.brand,
                    leading: Icon(Icons.info_outline, color: t.brand),
                    title: context.tr(
                      th: 'เกี่ยวกับแอปและข้อสงวนสิทธิ์',
                      en: 'About and disclaimer',
                    ),
                    trailing: Icon(Icons.chevron_right, color: t.inkMuted),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen(),
                      ),
                    ),
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
