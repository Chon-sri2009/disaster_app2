import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../services/sensor_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/warning_banner.dart';

// Sensors screen: water and vibration readings, limit warnings and (debug builds only) a demo slider.
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
            if (!sensors.isDemo) return _LiveStations(sensors: sensors);
            final reading = sensors.latest;
            return ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                Text(
                  context.tr(th: 'เซนเซอร์', en: 'Sensors'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.md),
                if (sensors.waterOverLimit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: WarningBanner(
                      kind: BannerKind.error,
                      message: context.tr(
                        th: 'ระดับน้ำเกินระดับปลอดภัยแล้ว',
                        en: 'Water level is over the safe limit.',
                      ),
                    ),
                  ),
                if (sensors.vibrationOverLimit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: WarningBanner(
                      kind: BannerKind.error,
                      message: context.tr(
                        th: 'ตรวจพบแรงสั่นสะเทือนสูง',
                        en: 'Strong vibration detected.',
                      ),
                    ),
                  ),
                _SensorCard(
                  title: context.tr(th: 'ระดับน้ำ', en: 'Water level'),
                  icon: Icons.water,
                  value: reading.waterCm,
                  unit: context.cmUnit,
                  limit: MockData.waterLimitCm,
                  decimals: 0,
                  over: sensors.waterOverLimit,
                ),
                const SizedBox(height: AppSpace.md),
                _SensorCard(
                  title: context.tr(th: 'แรงสั่นสะเทือน', en: 'Vibration'),
                  icon: Icons.vibration,
                  value: reading.vibrationG,
                  unit: 'g',
                  limit: MockData.vibrationLimitG,
                  decimals: 2,
                  over: sensors.vibrationOverLimit,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  context.tr(
                    th:
                        'ข้อมูลทดลอง ไม่ใช่ค่าจริง · อัปเดต ${context.clock(reading.time)} '
                        '(ทุก 2 วินาที)',
                    en:
                        'Demo data, not live · updated ${context.clock(reading.time)} '
                        '(every 2 seconds)',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                // The simulator is a developer tool: it never ships in release builds.
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    context.tr(
                      th: 'ทดลอง: จำลองระดับน้ำ',
                      en: 'Demo: simulate water level',
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    context.tr(
                      th: 'สำหรับทดลองเท่านั้น ค่าจะถูกแทนที่เมื่อเซนเซอร์อัปเดตครั้งถัดไป',
                      en: 'For demos only. The sensor timer replaces this value on its next update.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: reading.waterCm.clamp(0.0, MockData.waterMaxCm),
                    max: MockData.waterMaxCm,
                    divisions: 50,
                    label:
                        '${reading.waterCm.toStringAsFixed(0)} ${context.cmUnit}',
                    semanticFormatterCallback: (v) => context.tr(
                      th: '${v.round()} เซนติเมตร',
                      en: '${v.round()} centimeters',
                    ),
                    onChanged: sensors.simulateWater,
                  ),
                ],
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
    final status = over
        ? context.tr(th: 'เกินระดับปลอดภัย', en: 'Over the limit')
        : context.tr(th: 'อยู่ในเกณฑ์ปกติ', en: 'Within the limit');
    return Semantics(
      container: true,
      liveRegion: over,
      label: context.tr(
        th: '$title $shown $unit ระดับปลอดภัยไม่เกิน $limitText $unit $status',
        en: '$title $shown $unit, safe limit $limitText $unit, $status',
      ),
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
                      context.tr(
                        th: 'ระดับปลอดภัย: ไม่เกิน $limitText $unit',
                        en: 'Safe limit: $limitText $unit',
                      ),
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
                        Expanded(
                          child: Text(
                            status,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: fg,
                            ),
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

// Real stations from the backend: name, level word, water depth and age. A station with no
// usable reading says so; it is never drawn as Safe.
class _LiveStations extends StatelessWidget {
  const _LiveStations({required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = sensors.fetchedAt;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Text(
          context.tr(th: 'เซนเซอร์', en: 'Sensors'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpace.md),
        if (!sensors.isLive)
          WarningBanner(
            kind: BannerKind.offline,
            message: context.tr(
              th: 'ยังไม่ได้เชื่อมต่อเซนเซอร์',
              en: 'Not connected to sensors yet.',
            ),
          )
        else if (at == null)
          WarningBanner(
            kind: BannerKind.offline,
            message: context.tr(
              th: 'เชื่อมต่อเซนเซอร์ไม่ได้ ยังไม่มีข้อมูลสด',
              en: 'Cannot reach the sensors. No live data yet.',
            ),
          )
        else if (sensors.isStale)
          WarningBanner(
            kind: BannerKind.offline,
            message: context.tr(
              th: 'อัปเดตล่าสุด ${context.stamp(at)} ข้อมูลอาจไม่เป็นปัจจุบัน',
              en: 'Last updated ${context.stamp(at)}. May be out of date.',
            ),
          ),
        for (final s in sensors.stations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s.level == null
                  ? Icons.sensors_off
                  : context.tokens.styleFor(s.level!).icon,
            ),
            title: Text(s.name),
            subtitle: Text(
              s.level == null
                  ? context.tr(
                      th: 'ไม่มีข้อมูลที่เชื่อถือได้',
                      en: 'No reliable reading',
                    )
                  : '${context.levelLabel(s.level!)} · '
                        '${s.waterCm?.toStringAsFixed(0) ?? '-'} ${context.cmUnit}'
                        '${s.readingTime == null ? '' : ' · ${context.stamp(s.readingTime!)}'}',
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        Text(
          context.tr(
            th: 'เซนเซอร์ชุมชน ไม่ใช่เครื่องวัดทางการ',
            en: 'Community sensors, not official gauges.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
