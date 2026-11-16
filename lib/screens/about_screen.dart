import 'package:flutter/material.dart';

import '../data/emergency_numbers.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';

// About: disclaimer (content required by DEVELOPMENT_PLAN.md 9.4) and data sources (9.2, 5.7).
// DRAFT wording: the owner must rewrite it and Thai counsel must review it before release.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const disclaimer = [
    'This app is not an official government warning channel.',
    'Official warnings come from Cell Broadcast (T-Alert), DDPM, NDWC and TMD. '
        'Follow them and local officials first.',
    'Alerts here may be late, incomplete or wrong. No alert does not mean no danger.',
    'Community sensors are not official gauges.',
  ];

  static const sources = [
    (
      'Thai Meteorological Department (TMD)',
      'CAP alerts, public domain per the feed',
    ),
    ('OpenStreetMap contributors', 'Map tiles, © OpenStreetMap contributors'),
    ('OCHA / Royal Thai Survey Department', 'Admin boundaries, CC BY-IGO'),
    ('Sensor and alert data in this build', 'Mock data, not live readings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
      child: Text(text, style: theme.textTheme.titleLarge),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('About and disclaimer')),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              heading('Disclaimer'),
              for (final line in disclaimer)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(line, style: theme.textTheme.bodyLarge),
                ),
              Text(
                'In an emergency call ${EmergencyNumbers.sos.map((n) => '${n.number} (${n.service})').join(', ')}.',
                style: theme.textTheme.bodyLarge,
              ),
              heading('Data sources'),
              for (final s in sources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.$1),
                  subtitle: Text(s.$2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
