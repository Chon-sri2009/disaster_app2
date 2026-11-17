import 'package:flutter/material.dart';

import '../data/emergency_numbers.dart';
import '../l10n/l10n.dart';
import '../services/emergency_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
import 'settings_screen.dart';

// The icon for each emergency service, shared by this tab and Home's quick-call row.
IconData emergencyIcon(EmergencyNumber n) => switch (n.number) {
  '1669' => Icons.medical_services,
  '191' => Icons.local_police,
  '1784' => Icons.flood,
  _ => Icons.call,
};

// Call tab: one large card per emergency number. A tap opens the phone's dialer with the number
// filled in; the user still presses call, so a stray tap never places a call.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    // The header band paints behind the status bar, so only the sides and bottom are inset.
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandHeader(
            title: context.tr(th: 'โทรฉุกเฉิน', en: 'Emergency calls'),
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
                      for (final n in EmergencyNumbers.sos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: SoftTile(
                            semanticLabel: context.tr(
                              th: 'โทร ${n.number} ${context.serviceName(n)}',
                              en: 'Call ${n.number}, ${context.serviceName(n)}',
                            ),
                            onTap: () => EmergencyLauncher.call(n.number),
                            child: Row(
                              children: [
                                Container(
                                  width: AppSize.primaryButton,
                                  height: AppSize.primaryButton,
                                  decoration: BoxDecoration(
                                    color: t.brandSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(emergencyIcon(n), color: t.brand),
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.number,
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                      ),
                                      Text(
                                        context.serviceName(n),
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  context.tr(th: 'โทร', en: 'Call'),
                                  icon: Icons.call,
                                  color: t.brand,
                                  onColor: t.onBrand,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        context.tr(
                          th: 'แตะเพื่อเปิดหน้าโทรออกพร้อมเบอร์ แล้วกดโทรเอง',
                          en: 'Tap to open the dialer with the number filled in, then press call.',
                        ),
                        style: theme.textTheme.bodySmall,
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
