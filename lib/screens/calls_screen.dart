import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/emergency_numbers.dart';
import '../l10n/l10n.dart';
import '../services/emergency_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
import 'settings_screen.dart';

// The icon for each emergency service, shared by this tab and Home's quick-call row.
IconData emergencyIcon(EmergencyNumber n) => switch (n.number) {
  '1669' => Icons.medical_services,
  '191' => Icons.local_police,
  '1784' => Icons.flood,
  _ => Icons.call,
};

// Call tab: one ruled row per emergency number. A tap opens the phone's dialer with the number
// filled in; the user still presses call, so a stray tap never places a call.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
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
                  context.tr(th: 'โทรฉุกเฉิน', en: 'Emergency calls'),
                  trailing: SettingsButton(storage: storage),
                ),
                const SizedBox(height: AppSpace.sm),
                Container(height: AppStroke.rule, color: t.hairline),
                for (final n in EmergencyNumbers.sos)
                  RuledRow(
                    icon: emergencyIcon(n),
                    title: n.number,
                    titleStyle: theme.textTheme.displaySmall,
                    subtitle: context.serviceName(n),
                    subtitleStyle: theme.textTheme.titleSmall,
                    // The word is visible next to the icon, not the icon alone.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(th: 'โทร', en: 'Call'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: t.brand,
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Icon(Icons.call, color: t.brand),
                      ],
                    ),
                    semanticLabel: context.tr(
                      th: 'โทร ${n.number} ${context.serviceName(n)}',
                      en: 'Call ${n.number}, ${context.serviceName(n)}',
                    ),
                    onTap: () => EmergencyLauncher.call(n.number),
                  ),
                const SizedBox(height: AppSpace.md),
                Text(
                  context.tr(
                    th: 'แตะเพื่อเปิดหน้าโทรออกพร้อมเบอร์ แล้วกดโทรเอง',
                    en: 'Tap to open the dialer with the number filled in, then press call.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
