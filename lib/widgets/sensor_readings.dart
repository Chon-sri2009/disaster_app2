import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../models/alert_level.dart';
import '../services/sensor_service.dart';
import '../theme/app_tokens.dart';
import 'level_meter.dart';
import 'notice.dart';
import 'warning_banner.dart';

// Sensor readings for Home: the demo water and vibration gauges, or the live stations.
class SensorReadings extends StatelessWidget {
  const SensorReadings({super.key, required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sensors,
      builder: (context, _) => sensors.isDemo
          ? _DemoReadings(sensors: sensors)
          : _LiveStations(sensors: sensors),
    );
  }
}

class _DemoReadings extends StatelessWidget {
  const _DemoReadings({required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = sensors.latest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReadingBlock(
          title: context.tr(th: 'ระดับน้ำ', en: 'Water level'),
          icon: Icons.water,
          value: reading.waterCm,
          max: MockData.waterMaxCm,
          unit: context.cmUnit,
          spokenUnit: context.tr(th: 'เซนติเมตร', en: 'centimeters'),
          limit: MockData.waterLimitCm,
          decimals: 0,
          over: sensors.waterOverLimit,
        ),
        const SizedBox(height: AppSpace.sm),
        ReadingBlock(
          title: context.tr(th: 'แรงสั่นสะเทือน', en: 'Vibration'),
          icon: Icons.vibration,
          value: reading.vibrationG,
          max: MockData.vibrationLimitG * 2,
          unit: 'g',
          spokenUnit: 'g',
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
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.tokens.hairline,
                  width: AppStroke.frame,
                ),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.tune),
                title: Text(
                  context.tr(
                    th: 'ทดลอง: จำลองระดับน้ำ',
                    en: 'Demo: simulate water level',
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                expansionAnimationStyle: AnimationStyle(
                  duration: context.motion(AppMotion.base),
                  curve: Curves.easeOut,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              ),
            ),
          ),
      ],
    );
  }
}

// One measured value on the board: title and status, the value, its segmented gauge with the
// limit post, and the limit in words. Over the limit the block takes a danger frame and tint.
class ReadingBlock extends StatelessWidget {
  const ReadingBlock({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.max,
    required this.unit,
    required this.spokenUnit,
    required this.limit,
    required this.decimals,
    required this.over,
  });

  final String title;
  final IconData icon;
  final double value;
  final double max;
  final String unit;
  final String spokenUnit;
  final double limit;
  final int decimals;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final shown = value.toStringAsFixed(decimals);
    final limitText = limit.toStringAsFixed(decimals);
    final status = over
        ? context.tr(th: 'เกินระดับปลอดภัย', en: 'Over the limit')
        : context.tr(th: 'อยู่ในเกณฑ์ปกติ', en: 'Within the limit');
    final safe = t.tier(AlertTier.safe);
    return Semantics(
      container: true,
      liveRegion: over,
      label: context.tr(
        th: '$title $shown $spokenUnit ระดับปลอดภัยไม่เกิน $limitText $spokenUnit $status',
        en: '$title $shown $spokenUnit, safe limit $limitText $spokenUnit, $status',
      ),
      child: ExcludeSemantics(
        child: NoticeFrame(
          color: over ? t.errorBg : t.surface,
          borderColor: over ? t.dangerInk : t.ink,
          borderWidth: over ? AppStroke.heavy : AppStroke.frame,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: AppIconSize.md),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  Icon(
                    over ? Icons.dangerous : Icons.check_circle,
                    size: AppIconSize.sm,
                    color: over ? t.dangerInk : safe.onGround,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Flexible(
                    child: Text(
                      status,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: over ? t.dangerInk : safe.onGround,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                '$shown $unit',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: over ? t.dangerInk : t.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              SegmentedGauge(value: value, max: max, limit: limit),
              Text(
                context.tr(
                  th: 'ระดับปลอดภัย: ไม่เกิน $limitText $unit',
                  en: 'Safe limit: $limitText $unit',
                ),
                style: theme.textTheme.bodySmall,
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
    final t = context.tokens;
    final at = sensors.fetchedAt;
    final String? notice;
    if (!sensors.isLive) {
      notice = context.tr(
        th: 'ยังไม่ได้เชื่อมต่อเซนเซอร์',
        en: 'Not connected to sensors yet.',
      );
    } else if (at == null) {
      notice = context.tr(
        th: 'เชื่อมต่อเซนเซอร์ไม่ได้ ยังไม่มีข้อมูลสด',
        en: 'Cannot reach the sensors. No live data yet.',
      );
    } else if (sensors.isStale) {
      notice = context.tr(
        th: 'อัปเดตล่าสุด ${context.stamp(at)} ข้อมูลอาจไม่เป็นปัจจุบัน',
        en: 'Last updated ${context.stamp(at)}. May be out of date.',
      );
    } else {
      notice = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: WarningBanner(kind: BannerKind.offline, message: notice),
          ),
        for (final s in sensors.stations)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: NoticeFrame(
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: theme.textTheme.titleSmall),
                            Text(
                              s.level == null
                                  ? context.tr(
                                      th: 'ไม่มีข้อมูลที่เชื่อถือได้',
                                      en: 'No reliable reading',
                                    )
                                  : '${s.waterCm?.toStringAsFixed(0) ?? '-'} ${context.cmUnit}'
                                        '${s.readingTime == null ? '' : ' · ${context.stamp(s.readingTime!)}'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _StationLevel(level: s.level, tokens: t),
                  ],
                ),
              ),
            ),
          ),
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

// The right-hand cell of a station row: the tier field with icon and word, or an empty cell.
class _StationLevel extends StatelessWidget {
  const _StationLevel({required this.level, required this.tokens});

  final AlertLevel? level;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final l = level;
    final style = l == null ? null : tokens.styleFor(l);
    final fg = style?.onColor ?? tokens.inkMuted;
    return Container(
      constraints: const BoxConstraints(minWidth: AppSize.levelCell),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: style?.color ?? tokens.offlineBg,
        border: Border(
          left: BorderSide(color: tokens.ink, width: AppStroke.frame),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style?.icon ?? Icons.sensors_off, color: fg),
          Text(
            l == null ? '–' : context.levelLabel(l),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
