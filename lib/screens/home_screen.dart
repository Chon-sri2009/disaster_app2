import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../data/emergency_numbers.dart';
import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../services/alert_rules.dart';
import '../services/alert_service.dart';
import '../services/emergency_launcher.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/sos_hold_button.dart';
import '../widgets/warning_banner.dart';

// Home screen: alert level, water level, official alerts, and a pinned press-and-hold SOS button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.sensors,
    required this.location,
    this.alerts,
  });

  final SensorService sensors;
  final LocationService location;
  final AlertService? alerts;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Keeps track of whether the SOS is waiting for GPS.
class _HomeScreenState extends State<HomeScreen> {
  bool _locating = false;

  // Reads GPS, then shows the ready-made help message in a dialog.
  Future<void> _onSos() async {
    setState(() => _locating = true);
    final result = await widget.location.getCurrent();
    if (!mounted) return;
    setState(() => _locating = false);

    final point = result.point;
    final reason = result.issue == null
        ? ''
        : context.locationError(result.issue!);
    String? message;
    if (point != null) {
      final lat = point.latitude.toStringAsFixed(6);
      final lng = point.longitude.toStringAsFixed(6);
      // Local time plus the UTC offset, so a rescuer in another zone reads the right hour.
      final now = DateTime.now();
      final off = now.timeZoneOffset;
      final hh = off.inHours.abs().toString().padLeft(2, '0');
      final mm = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final time =
          '${now.toString().substring(0, 16)} UTC${off.isNegative ? '-' : '+'}$hh:$mm';
      // The person reading this may speak either language, so the message carries both.
      final cached = result.fromCache
          ? ' (ตำแหน่งที่บันทึกไว้ล่าสุด / last saved position)'
          : '';
      message =
          'SOS! ต้องการความช่วยเหลือ / I need help.\n'
          'ตำแหน่ง / Location: $lat, $lng$cached\n'
          'แผนที่ / Map: https://www.google.com/maps?q=$lat,$lng\n'
          'เวลา / Time: $time';
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _SosSheet(
        message: message,
        reason: reason,
        fromCache: result.fromCache,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= AppSize.wideBreakpoint;
        final content = _StatusColumn(
          sensors: widget.sensors,
          alerts: widget.alerts,
          position: widget.location.lastKnown,
        );
        if (wide) {
          // Tablet or landscape: status on the left, SOS panel pinned on the right.
          final diameter = (box.maxHeight - 120).clamp(120.0, 220.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ContentWidth(child: content),
                ),
              ),
              _SosPanel(
                busy: _locating,
                onConfirmed: _onSos,
                diameter: diameter,
                width: 320,
              ),
            ],
          );
        }
        // Phone portrait: status scrolls, SOS stays pinned in the thumb zone.
        return Column(
          children: [
            Expanded(child: SingleChildScrollView(child: content)),
            _SosPanel(
              busy: _locating,
              onConfirmed: _onSos,
              diameter: box.maxHeight >= 640 ? 192 : 160,
            ),
          ],
        );
      },
    );
  }
}

// The scrolling part of Home: level band, official alerts and the water meter.
class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.sensors, this.alerts, this.position});

  final SensorService sensors;
  final AlertService? alerts;
  final LatLng? position;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LevelBand(sensors: sensors, alerts: alerts, position: position),
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Official alerts come first: they outrank the community sensor below.
              if (alerts != null) _OfficialAlerts(alerts: alerts!),
              if (sensors.isDemo) _WaterMeter(sensors: sensors),
            ],
          ),
        ),
      ],
    );
  }
}

// A full-width colored band with the alert level as icon + word + advice (never color alone).
class _LevelBand extends StatelessWidget {
  const _LevelBand({required this.sensors, this.alerts, this.position});

  final SensorService sensors;
  final AlertService? alerts;
  final LatLng? position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([sensors, ?alerts]),
      builder: (context, _) {
        final p = position;
        final official = alerts != null && alerts!.hasSnapshot && p != null
            ? alerts!.levelAt(p)
            : null;
        final level = AlertRules.combine(sensors.level, official);
        final fromOfficial = level != null && level == official && level != sensors.level;
        final t = context.tokens;
        final style = level == null ? null : t.styleFor(level);
        final onColor = style?.onColor ?? t.ink;
        final at = sensors.fetchedAt;
        final String source;
        if (fromOfficial) {
          source = context.tr(
            th: 'ประกาศเตือนภัยทางการ ในพื้นที่ล่าสุดของคุณ',
            en: 'Official alert for your last known area',
          );
        } else if (sensors.isDemo) {
          source = context.tr(
            th: 'ข้อมูลทดลอง ไม่ใช่ค่าจริง',
            en: 'Demo data, not real',
          );
        } else if (!sensors.isLive) {
          source = context.tr(
            th: 'ยังไม่ได้เชื่อมต่อเซนเซอร์',
            en: 'Not connected to sensors yet',
          );
        } else if (at == null) {
          source = context.tr(
            th: 'เชื่อมต่อเซนเซอร์ไม่ได้',
            en: 'Cannot reach the sensors',
          );
        } else {
          source = context.tr(
            th:
                'จากเซนเซอร์ชุมชน · อัปเดต ${context.stamp(at)}'
                '${sensors.isStale ? ' (ข้อมูลอาจเก่า)' : ''}',
            en:
                'From community sensors · updated ${context.stamp(at)}'
                '${sensors.isStale ? ' (may be out of date)' : ''}',
          );
        }
        final label = level == null
            ? context.tr(th: 'ไม่มีข้อมูลสด', en: 'No live data')
            : context.levelLabel(level);
        final advice = level == null
            ? context.tr(
                th: 'อย่าถือว่าปลอดภัย โปรดติดตาม T-Alert และสายด่วน 1784',
                en: 'Do not assume it is safe. Watch T-Alert and the 1784 hotline.',
              )
            : context.levelAdvice(level);
        return Semantics(
          container: true,
          liveRegion: true,
          label: '$source: $label. $advice',
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              color: style?.color ?? t.hairline,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        style?.icon ?? Icons.sensors_off,
                        size: 56,
                        color: onColor,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onColor,
                              ),
                            ),
                            Text(
                              label,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: onColor,
                              ),
                            ),
                            Text(
                              advice,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: onColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Water level as a number plus a gauge bar with a tick at the safe limit.
class _WaterMeter extends StatelessWidget {
  const _WaterMeter({required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return ListenableBuilder(
      listenable: sensors,
      builder: (context, _) {
        final reading = sensors.latest;
        final over = sensors.waterOverLimit;
        final fill = (reading.waterCm / MockData.waterMaxCm).clamp(0.0, 1.0);
        final limit = MockData.waterLimitCm / MockData.waterMaxCm;
        final cm = context.cmUnit;
        final level = reading.waterCm.toStringAsFixed(0);
        final limitText = MockData.waterLimitCm.toStringAsFixed(0);
        return Semantics(
          container: true,
          label: context.tr(
            th:
                'ระดับน้ำ $level เซนติเมตร ระดับปลอดภัยไม่เกิน $limitText เซนติเมตร'
                '${over ? ' เกินระดับปลอดภัยแล้ว' : ''}',
            en:
                'Water level $level centimeters, safe limit $limitText centimeters'
                '${over ? ', over the limit' : ''}',
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(th: 'ระดับน้ำ', en: 'Water level'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$level $cm',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: over ? t.danger : t.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                LayoutBuilder(
                  builder: (context, box) {
                    return SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: t.hairline,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          AnimatedContainer(
                            duration: context.motion(AppMotion.base),
                            width: box.maxWidth * fill,
                            height: 16,
                            decoration: BoxDecoration(
                              color: over ? t.danger : t.accent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          Positioned(
                            left: box.maxWidth * limit - 1.5,
                            child: Container(
                              width: 3,
                              height: 24,
                              color: t.ink,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  context.tr(
                    th:
                        'ระดับปลอดภัยไม่เกิน $limitText $cm · '
                        'ข้อมูลทดลอง ไม่ใช่ค่าจริง · ${context.clock(reading.time)}',
                    en:
                        'Safe limit $limitText $cm · '
                        'demo data, not live · ${context.clock(reading.time)}',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// The pinned bottom (or right) panel holding the SOS button and its one-line hint.
class _SosPanel extends StatelessWidget {
  const _SosPanel({
    required this.busy,
    required this.onConfirmed,
    required this.diameter,
    this.width,
  });

  final bool busy;
  final VoidCallback onConfirmed;
  final double diameter;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width ?? double.infinity,
      // In the side panel the button sits in the middle of the full height.
      alignment: width != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: width == null ? BorderSide(color: t.hairline) : BorderSide.none,
          left: width != null ? BorderSide(color: t.hairline) : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The button shrinks to fit when the panel is short (landscape, large text).
          Flexible(
            child: LayoutBuilder(
              builder: (context, box) {
                final fit = [
                  diameter,
                  box.maxWidth,
                  box.maxHeight,
                ].reduce((a, b) => a < b ? a : b);
                return SosHoldButton(
                  busy: busy,
                  onConfirmed: onConfirmed,
                  diameter: fit,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            busy
                ? context.tr(
                    th: 'กำลังหาตำแหน่งของคุณ…',
                    en: 'Finding your location…',
                  )
                : context.tr(
                    th: 'กดค้าง 1.5 วินาทีเพื่อส่งตำแหน่งของคุณ',
                    en: 'Hold for 1.5 seconds to share your location',
                  ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// Official alerts with sender and time. With no backend yet it says so plainly instead of
// showing an invented warning.
class _OfficialAlerts extends StatelessWidget {
  const _OfficialAlerts({required this.alerts});

  final AlertService alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: alerts,
      builder: (context, _) {
        final at = alerts.fetchedAt;
        final Widget body;
        if (at == null) {
          body = WarningBanner(
            kind: BannerKind.offline,
            message: context.tr(
              th:
                  'แอปนี้ยังไม่ได้เชื่อมต่อประกาศเตือนภัยทางการ '
                  'โปรดติดตาม T-Alert และสายด่วน 1784 ควบคู่กัน',
              en:
                  'This app is not connected to official alerts yet. '
                  'Please also watch T-Alert and the 1784 hotline.',
            ),
          );
        } else {
          final shown = alerts.visibleAlerts;
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (alerts.isStale)
                WarningBanner(
                  kind: BannerKind.offline,
                  message: context.tr(
                    th:
                        'อัปเดตประกาศล่าสุด ${context.stamp(at)} '
                        'ข้อมูลอาจไม่เป็นปัจจุบัน',
                    en:
                        'Alerts last updated ${context.stamp(at)}. '
                        'They may be out of date.',
                  ),
                ),
              if (shown.isEmpty && !alerts.isStale)
                Text(
                  context.tr(
                    th: 'ไม่มีประกาศเตือนภัยในพื้นที่ · ตรวจล่าสุด ${context.stamp(at)}',
                    en: 'No alerts for your area · checked ${context.stamp(at)}',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              for (final a in shown)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: WarningBanner(
                    message:
                        '${context.levelLabel(a.level)} · ${a.sender} · '
                        '${context.stamp(a.sent)}\n'
                        '${a.headline[context.isThai ? 'th' : 'en'] ?? a.headline['th'] ?? a.headline.values.first}',
                  ),
                ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: body,
        );
      },
    );
  }
}

// What opens after a confirmed SOS: calling comes first, the ready-made message second.
class _SosSheet extends StatelessWidget {
  const _SosSheet({
    required this.message,
    required this.reason,
    required this.fromCache,
  });

  // Null when no position (fresh or saved) is available.
  final String? message;
  final String reason;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final text = message;
    final primary = EmergencyNumbers.medical;
    final others = EmergencyNumbers.sos.where((n) => n != primary);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        0,
        AppSpace.md,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text == null
                ? context.tr(
                    th: 'หาตำแหน่งของคุณไม่ได้',
                    en: 'Cannot find your location',
                  )
                : context.tr(th: 'ขอความช่วยเหลือ', en: 'Ask for help'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.md),
          if (text == null)
            WarningBanner(
              kind: BannerKind.error,
              message: context.tr(
                th:
                    '$reason ยังไม่มีตำแหน่งที่บันทึกไว้ '
                    'ถ้าอยู่ในอันตราย โทรเบอร์ฉุกเฉินได้เลย',
                en:
                    '$reason No saved position is available. '
                    'If you are in danger, call an emergency number.',
              ),
            ),
          if (text != null && fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: WarningBanner(
                kind: BannerKind.error,
                message: context.tr(
                  th: 'อ่าน GPS ไม่สำเร็จ ($reason) จึงใช้ตำแหน่งที่บันทึกไว้ล่าสุด',
                  en: 'GPS failed ($reason) so the last saved position is used.',
                ),
              ),
            ),
          if (text != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: t.ground,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: t.hairline),
              ),
              child: SelectableText(text),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: t.onDanger,
            ),
            onPressed: () => EmergencyLauncher.call(primary.number),
            icon: const Icon(Icons.call),
            label: Text(
              context.tr(
                th: 'โทร ${primary.number} ${context.serviceName(primary)}',
                en: 'Call ${primary.number} ${context.serviceName(primary)}',
              ),
            ),
          ),
          if (text != null) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => EmergencyLauncher.sms(const [], text),
                    icon: const Icon(Icons.sms),
                    label: Text(context.tr(th: 'ส่ง SMS', en: 'SMS')),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: text)),
                    icon: const Icon(Icons.share),
                    label: Text(context.tr(th: 'แชร์', en: 'Share')),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.sm,
            children: [
              for (final n in others)
                TextButton.icon(
                  onPressed: () => EmergencyLauncher.call(n.number),
                  icon: const Icon(Icons.call),
                  label: Text('${n.number} ${context.serviceName(n)}'),
                ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr(th: 'ปิด', en: 'Close')),
          ),
        ],
      ),
    );
  }
}
