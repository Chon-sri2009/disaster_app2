import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../services/sensor_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/warning_banner.dart';

// Sensors screen: live water and vibration readings, limit warnings and a demo slider.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key, required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ContentWidth(
        child: ListenableBuilder(
          listenable: sensors,
          builder: (context, _) {
            final reading = sensors.latest;
            return ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                Text('Sensors', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpace.md),
                if (sensors.waterOverLimit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.md),
                    child: WarningBanner(
                      kind: BannerKind.error,
                      message: 'Water level passed the safe limit!',
                    ),
                  ),
                if (sensors.vibrationOverLimit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.md),
                    child: WarningBanner(
                      kind: BannerKind.error,
                      message: 'Strong vibration detected!',
                    ),
                  ),
                _SensorCard(
                  title: 'Water level',
                  icon: Icons.water,
                  value: reading.waterCm,
                  unit: 'cm',
                  limit: MockData.waterLimitCm,
                  decimals: 0,
                  over: sensors.waterOverLimit,
                ),
                const SizedBox(height: AppSpace.md),
                _SensorCard(
                  title: 'Vibration',
                  icon: Icons.vibration,
                  value: reading.vibrationG,
                  unit: 'g',
                  limit: MockData.vibrationLimitG,
                  decimals: 2,
                  over: sensors.vibrationOverLimit,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Mock data · updated ${reading.time.toString().substring(11, 19)} '
                  '(every 2 seconds)',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Demo: simulate water level',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'For demos only. The sensor timer replaces this value on its next update.',
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: reading.waterCm.clamp(0.0, MockData.waterMaxCm),
                  max: MockData.waterMaxCm,
                  divisions: 50,
                  label: '${reading.waterCm.toStringAsFixed(0)} cm',
                  semanticFormatterCallback: (v) => '${v.round()} centimeters',
                  onChanged: sensors.simulateWater,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Card for one sensor: solid danger fill with icon and text when over the limit, plain otherwise.
class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.unit,
    required this.limit,
    required this.decimals,
    required this.over,
  });

  final String title;
  final IconData icon;
  final double value;
  final String unit;
  final double limit;
  final int decimals;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final fg = over ? t.onDanger : t.ink;
    final muted = over ? t.onDanger : t.inkMuted;
    final shown = value.toStringAsFixed(decimals);
    final limitText = limit.toStringAsFixed(decimals);
    return Semantics(
      container: true,
      liveRegion: over,
      label:
          '$title $shown $unit, safe limit $limitText $unit, '
          '${over ? 'over the limit' : 'within the limit'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: over ? t.danger : t.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: over ? t.danger : t.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: over ? t.onDanger : t.accent),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(color: fg),
                    ),
                    Text(
                      '$shown $unit',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: fg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Safe limit: $limitText $unit',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        Icon(
                          over ? Icons.dangerous : Icons.check_circle,
                          size: 24,
                          color: over
                              ? t.onDanger
                              : t.tier(AlertTier.safe).color,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          over ? 'OVER LIMIT' : 'WITHIN LIMIT',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
