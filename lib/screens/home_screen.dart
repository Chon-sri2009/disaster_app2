import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../data/emergency_numbers.dart';
import '../data/mock_data.dart';
import '../models/alert_level.dart';
import '../l10n/l10n.dart';
import '../services/alert_rules.dart';
import '../services/alert_service.dart';
import '../services/emergency_launcher.dart';
import '../services/location_service.dart';
import '../services/nearby.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/level_meter.dart';
import '../widgets/soft_ui.dart';
import '../widgets/sos_hold_button.dart';
import '../widgets/warning_banner.dart';
import 'calls_screen.dart';
import 'settings_screen.dart';

// Home: the header band with the press-and-hold SOS card pinned over its edge, then the water
// level, quick calls, the nearest shelter and official notices.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.sensors,
    required this.location,
    required this.storage,
    this.alerts,
    this.onOpenMap,
  });

  final SensorService sensors;
  final LocationService location;
  final StorageService storage;
  final AlertService? alerts;
  final VoidCallback? onOpenMap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Keeps track of whether the SOS is waiting for GPS.
class _HomeScreenState extends State<HomeScreen> {
  bool _locating = false;

  // Reads GPS, then shows the ready-made help message in a sheet.
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
      final place = await widget.location.describe(point);
      if (!mounted) return;
      final where = context.placeText(place);
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
          'ที่อยู่ / Address: ${where.isEmpty ? '-' : where}$cached\n'
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
        final tall = box.maxHeight >= AppSize.sosHeightTallScreen;
        final sos = SosHoldButton(
          busy: _locating,
          onConfirmed: _onSos,
          height: tall ? AppSize.sosHeight : AppSize.sosHeightCompact,
        );
        // The header band and SOS stay put at the top; the cards scroll beneath them. The band
        // paints behind the status bar, so only the sides are inset here.
        return SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.sensors,
                  ?widget.alerts,
                  widget.storage,
                ]),
                builder: (context, _) {
                  final level = homeLevel(
                    widget.sensors,
                    widget.alerts,
                    widget.storage,
                  ).level;
                  // At warning and danger the whole band takes the tier color.
                  final loud =
                      level == AlertLevel.warning || level == AlertLevel.danger;
                  final style = loud ? context.tokens.styleFor(level!) : null;
                  return BrandHeader(
                    eyebrow: box.maxHeight < AppSize.railMinHeight
                        ? null
                        : widget.storage.lastPosition == null
                        ? context.tr(
                            th: 'ยังไม่ทราบพื้นที่',
                            en: 'Area not known yet',
                          )
                        : context.tr(
                            th: 'พื้นที่ตำแหน่งล่าสุดของคุณ',
                            en: 'Your last known area',
                          ),
                    title: context.tr(
                      th: 'แจ้งภัยและช่วยเหลือ',
                      en: 'Disaster Alert',
                    ),
                    trailing: SettingsButton(storage: widget.storage),
                    color: style?.color,
                    onColor: style?.onColor,
                    below: ContentWidth(child: sos),
                  );
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: ContentWidth(
                    child: _Board(
                      sensors: widget.sensors,
                      alerts: widget.alerts,
                      storage: widget.storage,
                      onOpenMap: widget.onOpenMap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// The level Home shows: the sensors' level and the official alert for the last known area,
// whichever is worse. fromOfficial says the official alert decided it.
({AlertLevel? level, bool fromOfficial}) homeLevel(
  SensorService sensors,
  AlertService? alerts,
  StorageService storage,
) {
  final LatLng? p = storage.lastPosition;
  final official = alerts != null && alerts.hasSnapshot && p != null
      ? alerts.levelAt(p)
      : null;
  final level = AlertRules.combine(sensors.level, official);
  final fromOfficial =
      level != null && level == official && level != sensors.level;
  return (level: level, fromOfficial: fromOfficial);
}

// The scrolling cards: water level, quick calls, nearest shelter and official notices.
class _Board extends StatelessWidget {
  const _Board({
    required this.sensors,
    required this.storage,
    this.alerts,
    this.onOpenMap,
  });

  final SensorService sensors;
  final StorageService storage;
  final AlertService? alerts;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LevelCard(sensors: sensors, alerts: alerts, storage: storage),
          const SizedBox(height: AppSpace.md),
          const _QuickCalls(),
          _NearestShelter(storage: storage, onOpenMap: onOpenMap),
          if (alerts != null) _OfficialAlerts(alerts: alerts!),
        ],
      ),
    );
  }
}

// The water-level card: the tier's icon, step and word (never color alone), the advice, the
// 4-step meter and where the level came from. At warning and danger the whole card fills with
// the tier color; below that it is a white card with tier-colored marks.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.sensors, required this.storage, this.alerts});

  final SensorService sensors;
  final StorageService storage;
  final AlertService? alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([sensors, ?alerts]),
      builder: (context, _) {
        final (:level, :fromOfficial) = homeLevel(sensors, alerts, storage);
        final p = storage.lastPosition;
        final t = context.tokens;
        final style = level == null ? null : t.styleFor(level);
        final loud = level == AlertLevel.warning || level == AlertLevel.danger;
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
        final step = level == null
            ? null
            : context.tr(
                th: 'ระดับ ${level.index + 1} จาก 4',
                en: 'Level ${level.index + 1} of 4',
              );
        // Where the level applies and when it was posted. Never a bare time for data that is
        // not live.
        final area = p == null
            ? context.tr(th: 'ยังไม่ทราบพื้นที่', en: 'Area not known yet')
            : context.tr(
                th: 'พื้นที่ตำแหน่งล่าสุดของคุณ',
                en: 'Your last known area',
              );
        final posted = sensors.isDemo
            ? context.tr(
                th: 'ทดลอง ${context.clock(sensors.latest.time)}',
                en: 'Demo ${context.clock(sensors.latest.time)}',
              )
            : at == null
            ? context.tr(th: 'ไม่มีข้อมูลสด', en: 'No live data')
            : context.stamp(at);

        // Loud: everything in the tier's on-color over its field. Calm: ink on white, with the
        // tier color on the icon disc and the level word.
        final fg = loud ? style!.onColor : t.ink;
        final wordColor = loud ? style!.onColor : (style?.onGround ?? t.ink);
        final discColor = loud
            ? style!.onColor.withValues(alpha: 0.18)
            : (style?.color ?? t.offlineBg);
        final discIcon = loud ? style!.onColor : (style?.onColor ?? t.inkMuted);
        return Semantics(
          container: true,
          liveRegion: true,
          label: '$area, $posted. $label. ${step ?? ''} $advice. $source',
          child: ExcludeSemantics(
            child: SoftCard(
              color: loud ? style!.color : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(th: 'ระดับน้ำ', en: 'Water level'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fg,
                          ),
                        ),
                      ),
                      Flexible(
                        child: StatusPill(
                          posted,
                          icon: Icons.schedule,
                          color: loud ? t.surface : t.ground,
                          onColor: loud ? t.ink : t.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: context.motion(AppMotion.slow),
                        width: AppSize.primaryButton,
                        height: AppSize.primaryButton,
                        decoration: BoxDecoration(
                          color: discColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          style?.icon ?? Icons.sensors_off,
                          size: AppIconSize.lg,
                          color: discIcon,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (step != null)
                              Text(
                                step,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: loud ? fg : t.inkMuted,
                                ),
                              ),
                            Text(
                              label,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: wordColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    advice,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  // The meter keeps its own white well on a loud card, so every step's color
                  // still reads.
                  Container(
                    padding: loud
                        ? const EdgeInsets.all(AppSpace.sm + AppSpace.xs)
                        : EdgeInsets.zero,
                    decoration: loud
                        ? BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LevelMeter(level: level),
                        const SizedBox(height: AppSpace.sm),
                        Text(source, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// A row of round shortcuts, one per emergency number; a tap opens the dialer (as on the Call tab).
class _QuickCalls extends StatelessWidget {
  const _QuickCalls();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            context.tr(th: 'โทรด่วน', en: 'Quick call'),
            inCard: true,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final n in EmergencyNumbers.sos)
                Flexible(
                  child: RoundChip(
                    icon: emergencyIcon(n),
                    label: n.number,
                    semanticLabel: context.tr(
                      th: 'โทร ${n.number} ${context.serviceName(n)}',
                      en: 'Call ${n.number}, ${context.serviceName(n)}',
                    ),
                    onTap: () => EmergencyLauncher.call(n.number),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// The nearest shelter with directions, or (position unknown) a way into the shelter map.
class _NearestShelter extends StatelessWidget {
  const _NearestShelter({required this.storage, this.onOpenMap});

  final StorageService storage;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final shelters = storage.shelters;
        if (shelters.isEmpty) return const SizedBox.shrink();
        final t = context.tokens;
        final from = storage.lastPosition;
        // Sample shelters must never pass for real ones (PRODUCT principle 5).
        final sample = MockData.isDemoShelterList(shelters)
            ? StatusPill(
                context.tr(th: 'ตัวอย่าง', en: 'Sample'),
                icon: Icons.science_outlined,
                color: t.offlineBg,
                onColor: t.ink,
              )
            : null;
        final title = SectionLabel(
          from == null
              ? context.tr(th: 'ศูนย์พักพิง', en: 'Shelters')
              : context.tr(th: 'ศูนย์พักพิงใกล้สุด', en: 'Nearest shelter'),
          trailing: sample,
          inCard: true,
        );
        final note = sample == null
            ? null
            : Text(
                context.tr(
                  th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                  en: 'Sample, not real shelters',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              );
        final Widget body;
        if (from == null) {
          body = AccentRow(
            accent: t.brand,
            leading: Icon(Icons.home_work, color: t.brand),
            title: context.tr(
              th: '${shelters.length} แห่งในเครื่องนี้',
              en: '${shelters.length} saved on this phone',
            ),
            subtitle: context.tr(
              th: 'ยังไม่ทราบตำแหน่งของคุณ ดูบนแผนที่',
              en: 'Your position is not known yet. See the map.',
            ),
            trailing: Icon(Icons.chevron_right, color: t.inkMuted),
            onTap: onOpenMap,
          );
        } else {
          final s = Nearby.sorted(shelters, from).first;
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccentRow(
                accent: t.brand,
                leading: Icon(Icons.home_work, color: t.brand),
                title: s.name,
                titleStyle: Theme.of(context).textTheme.titleMedium,
                subtitle: context.shelterCapacity(s.capacity),
                trailing: StatusPill(
                  context.distance(Nearby.metersTo(from, s)),
                  icon: Icons.near_me,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              FilledButton.icon(
                onPressed: () => EmergencyLauncher.navigate(s.lat, s.lng),
                icon: const Icon(Icons.directions),
                label: Text(
                  context.tr(th: 'นำทางไปที่นี่', en: 'Get directions'),
                ),
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, ?note, body],
            ),
          ),
        );
      },
    );
  }
}

// Official notices with level, sender and time. With no backend yet it says so plainly instead
// of showing an invented warning.
class _OfficialAlerts extends StatelessWidget {
  const _OfficialAlerts({required this.alerts});

  final AlertService alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return ListenableBuilder(
      listenable: alerts,
      builder: (context, _) {
        final at = alerts.fetchedAt;
        final children = <Widget>[
          SectionLabel(
            context.tr(th: 'ประกาศทางการ', en: 'Official notices'),
            inCard: true,
          ),
        ];
        if (at == null) {
          children.add(
            WarningBanner(
              kind: BannerKind.offline,
              message: context.tr(
                th:
                    'แอปนี้ยังไม่ได้เชื่อมต่อประกาศเตือนภัยทางการ '
                    'โปรดติดตาม T-Alert และสายด่วน 1784 ควบคู่กัน',
                en:
                    'This app is not connected to official alerts yet. '
                    'Please also watch T-Alert and the 1784 hotline.',
              ),
            ),
          );
        } else {
          final shown = alerts.visibleAlerts;
          if (alerts.isStale) {
            children.add(
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
            );
          }
          if (shown.isEmpty && !alerts.isStale) {
            children.add(
              Text(
                context.tr(
                  th: 'ไม่มีประกาศเตือนภัยในพื้นที่ · ตรวจล่าสุด ${context.stamp(at)}',
                  en: 'No alerts for your area · checked ${context.stamp(at)}',
                ),
                style: theme.textTheme.bodyMedium,
              ),
            );
          }
          for (final (i, a) in shown.indexed) {
            final style = t.styleFor(a.level);
            final headline =
                a.headline[context.isThai ? 'th' : 'en'] ??
                a.headline['th'] ??
                a.headline.values.first;
            if (i > 0) children.add(const Divider());
            children.add(
              Semantics(
                container: true,
                label:
                    '${context.levelLabel(a.level)}. $headline. '
                    '${a.sender}, ${context.stamp(a.sent)}',
                child: ExcludeSemantics(
                  child: AccentRow(
                    accent: style.color,
                    title: headline,
                    subtitle: '${a.sender} · ${context.stamp(a.sent)}',
                    trailing: StatusPill(
                      context.levelLabel(a.level),
                      icon: style.icon,
                      color: style.color,
                      onColor: style.onColor,
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
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
          const SizedBox(height: AppSpace.md),
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
            SectionLabel(
              context.tr(th: 'ส่งตำแหน่งของคุณ', en: 'Send your location'),
            ),
            SoftCard(
              color: t.ground,
              child: SelectableText(text, style: theme.textTheme.bodyMedium),
            ),
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
          SectionLabel(context.tr(th: 'เบอร์อื่น', en: 'Other numbers')),
          for (final n in others)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: OutlinedButton.icon(
                onPressed: () => EmergencyLauncher.call(n.number),
                icon: const Icon(Icons.call),
                label: Text('${n.number} ${context.serviceName(n)}'),
              ),
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
