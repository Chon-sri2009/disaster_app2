import 'package:flutter/material.dart';

import '../data/emergency_numbers.dart';
import '../l10n/l10n.dart';
import '../services/emergency_launcher.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice.dart';
import 'settings_screen.dart';

// Call tab: one large framed tile per emergency number. A tap opens the phone's dialer with the
// number filled in; the user still presses call, so a stray tap never places a call.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
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
                          child: NoticeTile(
                            semanticLabel: context.tr(
                              th: 'โทร ${n.number} ${context.serviceName(n)}',
                              en: 'Call ${n.number}, ${context.serviceName(n)}',
                            ),
                            onTap: () => EmergencyLauncher.call(n.number),
                            child: Row(
                              children: [
                                const Icon(Icons.call, size: AppIconSize.lg),
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
                                const Icon(Icons.chevron_right),
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
