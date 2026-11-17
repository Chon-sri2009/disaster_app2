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
import '../services/nearby.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/level_meter.dart';
import '../widgets/notice.dart';
import '../widgets/sensor_readings.dart';
import '../widgets/sos_hold_button.dart';
import '../widgets/warning_banner.dart';
import 'settings_screen.dart';

// Home: the level notice, one-tap calls, the nearest shelter, official notices and sensor
// readings, with the press-and-hold SOS block pinned in the thumb zone.
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
        final content = _Board(
          sensors: widget.sensors,
          alerts: widget.alerts,
          storage: widget.storage,
          onOpenMap: widget.onOpenMap,
          showCalls: !wide,
        );
        if (wide) {
          // Tablet or landscape: the board on the left, SOS and calls pinned on the right.
          final sosHeight = (box.maxHeight * 0.3).clamp(
            AppSize.sosHeight,
            AppSize.sosHeight * 2,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: SafeArea(
                    bottom: false,
                    child: ContentWidth(child: content),
                  ),
                ),
              ),
              Container(
                width: AppSize.sidePanelWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: context.tokens.ink,
                      width: AppStroke.heavy,
                    ),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SosHoldButton(
                          busy: _locating,
                          onConfirmed: _onSos,
                          height: sosHeight,
                        ),
                        SectionLabel(
                          context.tr(th: 'โทรฉุกเฉิน', en: 'Emergency calls'),
                        ),
                        const _CallTiles(vertical: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        // Phone portrait: the board scrolls, SOS stays pinned in the thumb zone.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SafeArea(bottom: false, child: content),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.tokens.ground,
                border: Border(
                  top: BorderSide(
                    color: context.tokens.ink,
                    width: AppStroke.heavy,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.sm),
                child: SosHoldButton(
                  busy: _locating,
                  onConfirmed: _onSos,
                  height: box.maxHeight >= AppSize.sosHeightTallScreen
                      ? AppSize.sosHeight
                      : AppSize.sosHeightCompact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// The scrolling board: header, level notice, calls, nearest shelter, official notices, readings.
class _Board extends StatelessWidget {
  const _Board({
    required this.sensors,
    required this.storage,
    required this.showCalls,
    this.alerts,
    this.onOpenMap,
  });

  final SensorService sensors;
  final StorageService storage;
  final AlertService? alerts;
  final VoidCallback? onOpenMap;
  final bool showCalls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: context.tr(th: 'แจ้งภัยและช่วยเหลือ', en: 'Disaster Alert'),
          trailing: SettingsButton(storage: storage),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LevelNotice(sensors: sensors, alerts: alerts, storage: storage),
              if (showCalls) ...[
                SectionLabel(
                  context.tr(th: 'โทรฉุกเฉิน', en: 'Emergency calls'),
                ),
                const _CallTiles(vertical: false),
              ],
              _NearestShelter(storage: storage, onOpenMap: onOpenMap),
              // Official notices outrank the community sensors below them.
              if (alerts != null) _OfficialAlerts(alerts: alerts!),
              SectionLabel(
                context.tr(th: 'ค่าจากเซนเซอร์', en: 'Sensor readings'),
              ),
              SensorReadings(sensors: sensors),
            ],
          ),
        ),
      ],
    );
  }
}

// The level notice: a heavy-framed block in the tier's color (icon + word + advice, never color
// alone), the 4-step scale beneath it, and where the level came from.
class _LevelNotice extends StatelessWidget {
  const _LevelNotice({
    required this.sensors,
    required this.storage,
    this.alerts,
  });

  final SensorService sensors;
  final StorageService storage;
  final AlertService? alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([sensors, ?alerts]),
      builder: (context, _) {
        final LatLng? p = storage.lastPosition;
        final official = alerts != null && alerts!.hasSnapshot && p != null
            ? alerts!.levelAt(p)
            : null;
        final level = AlertRules.combine(sensors.level, official);
        final fromOfficial =
            level != null && level == official && level != sensors.level;
        final t = context.tokens;
        final style = level == null ? null : t.styleFor(level);
        final field = style?.color ?? t.offlineBg;
        final onField = style?.onColor ?? t.ink;
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
        // The notice's posting line: where it applies and when it was posted. It never shows a
        // bare time for data that is not live.
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
        return Semantics(
          container: true,
          liveRegion: true,
          label: '$area, $posted. $label. ${step ?? ''} $advice. $source',
          child: ExcludeSemantics(
            child: DecoratedBox(
              // In front of the tier field, so the frame shows on every edge.
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: t.ink, width: AppStroke.heavy),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: t.ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: AppIconSize.sm,
                          color: t.ground,
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Expanded(
                          child: Text(
                            area,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: t.ground,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          posted,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: t.ground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: context.motion(AppMotion.slow),
                    color: field,
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          style?.icon ?? Icons.sensors_off,
                          size: AppIconSize.xl,
                          color: onField,
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
                                    color: onField,
                                  ),
                                ),
                              Text(
                                label,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: onField,
                                ),
                              ),
                              Text(
                                advice,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: onField,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(
                        top: BorderSide(color: t.ink, width: AppStroke.heavy),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.sm,
                    ),
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

// One framed tile per emergency number: one tap opens the dialer (the user still presses call).
class _CallTiles extends StatelessWidget {
  const _CallTiles({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = [
      for (final n in EmergencyNumbers.sos)
        NoticeTile(
          semanticLabel: context.tr(
            th: 'โทร ${n.number} ${context.serviceName(n)}',
            en: 'Call ${n.number}, ${context.serviceName(n)}',
          ),
          onTap: () => EmergencyLauncher.call(n.number),
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.call, size: AppIconSize.sm),
                  const SizedBox(width: AppSpace.xs),
                  Flexible(
                    child: Text(
                      n.number,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                context.serviceName(n),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.tokens.ink,
                ),
              ),
            ],
          ),
        ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpace.sm),
            tile,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpace.sm),
            Expanded(child: tile),
          ],
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
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final shelters = storage.shelters;
        if (shelters.isEmpty) return const SizedBox.shrink();
        final from = storage.lastPosition;
        final title = SectionLabel(
          from == null
              ? context.tr(th: 'ศูนย์พักพิง', en: 'Shelters')
              : context.tr(th: 'ศูนย์พักพิงใกล้สุด', en: 'Nearest shelter'),
        );
        // Sample shelters must never pass for real ones (PRODUCT principle 5).
        final heading = MockData.isDemoShelterList(shelters)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: NoticeTag(
                      context.tr(
                        th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                        en: 'Sample, not real shelters',
                      ),
                    ),
                  ),
                ],
              )
            : title;
        if (from == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              NoticeTile(
                onTap: onOpenMap,
                child: Row(
                  children: [
                    const Icon(Icons.home_work, size: AppIconSize.lg),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              th: '${shelters.length} แห่งในเครื่องนี้',
                              en: '${shelters.length} saved on this phone',
                            ),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            context.tr(
                              th: 'ยังไม่ทราบตำแหน่งของคุณ ดูบนแผนที่',
                              en: 'Your position is not known yet. See the map.',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          );
        }
        final s = Nearby.sorted(shelters, from).first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            NoticeFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.home_work, size: AppIconSize.lg),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: theme.textTheme.titleMedium),
                            Text(
                              '${context.distance(Nearby.metersTo(from, s))} · '
                              '${context.shelterCapacity(s.capacity)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
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
              ),
            ),
          ],
        );
      },
    );
  }
}

// Official notices with sender and time. With no backend yet it says so plainly instead of
// showing an invented warning.
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
          SectionLabel(context.tr(th: 'ประกาศทางการ', en: 'Official notices')),
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
          for (final a in shown) {
            final style = t.styleFor(a.level);
            final headline =
                a.headline[context.isThai ? 'th' : 'en'] ??
                a.headline['th'] ??
                a.headline.values.first;
            children.add(
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Semantics(
                  container: true,
                  label:
                      '${context.levelLabel(a.level)}. $headline. '
                      '${a.sender}, ${context.stamp(a.sent)}',
                  child: ExcludeSemantics(
                    child: NoticeFrame(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: style.color,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                              vertical: AppSpace.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  style.icon,
                                  size: AppIconSize.sm,
                                  color: style.onColor,
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    context.levelLabel(a.level),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: style.onColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  context.stamp(a.sent),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: style.onColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headline,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  a.sender,
                                  style: theme.textTheme.bodySmall,
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
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
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
              background: t.surface,
            ),
            NoticeFrame(
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
          SectionLabel(
            context.tr(th: 'เบอร์อื่น', en: 'Other numbers'),
            background: t.surface,
          ),
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
