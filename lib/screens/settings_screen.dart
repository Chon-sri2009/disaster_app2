import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
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

// Settings: the app language, day or night board, and the About page. Each choice is a ruled row
// with the word, an optional icon and a check on the one in use.
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
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.lg,
              ),
              children: [
                Section(
                  title: context.tr(th: 'ภาษา', en: 'Language'),
                  children: [
                    // Each option is written in its own language, so either reader can find it.
                    _Choice(
                      title: 'ภาษาไทย',
                      selected: storage.language == AppLang.th,
                      onTap: () => storage.setLanguage(AppLang.th),
                    ),
                    _Choice(
                      title: 'English',
                      selected: storage.language == AppLang.en,
                      onTap: () => storage.setLanguage(AppLang.en),
                    ),
                  ],
                ),
                Section(
                  title: context.tr(th: 'ธีม', en: 'Theme'),
                  children: [
                    _Choice(
                      icon: Icons.brightness_auto,
                      title: context.tr(th: 'ตามเครื่อง', en: 'Phone'),
                      selected: storage.themeMode == ThemeMode.system,
                      onTap: () => storage.setThemeMode(ThemeMode.system),
                    ),
                    _Choice(
                      icon: Icons.light_mode,
                      title: context.tr(th: 'สว่าง', en: 'Light'),
                      selected: storage.themeMode == ThemeMode.light,
                      onTap: () => storage.setThemeMode(ThemeMode.light),
                    ),
                    _Choice(
                      icon: Icons.dark_mode,
                      title: context.tr(th: 'มืด', en: 'Dark'),
                      selected: storage.themeMode == ThemeMode.dark,
                      onTap: () => storage.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Container(height: AppStroke.rule, color: t.hairline),
                RuledRow(
                  icon: Icons.info_outline,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One choice of a group: the check shows the one in use; the space stays so words line up.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String title;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RuledRow(
      icon: icon,
      title: title,
      selected: selected,
      trailing: selected
          ? Icon(Icons.check, color: t.brand)
          : const SizedBox(width: AppIconSize.md, height: AppIconSize.md),
      onTap: onTap,
    );
  }
}
