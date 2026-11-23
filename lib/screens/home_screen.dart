import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../services/place_lookup.dart';
import '../services/province_locator.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
import '../widgets/soft_ui.dart';
import '../widgets/warning_banner.dart';
import 'alert_detail_screen.dart';
import 'alert_history_screen.dart';
import 'calls_screen.dart';
import 'settings_screen.dart';

// Home: the title, the level slab, the SOS bar (pinned, or fixed on short screens), then ruled
// sections for quick calls, the nearest shelter and official notices.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.sensors,
    required this.location,
    required this.storage,
    this.alerts,
    this.provinces,
    this.onOpenMap,
  });

  final SensorService sensors;
  final LocationService location;
  final StorageService storage;
  final AlertService? alerts;
  // Null until the boundary file is loaded (or if it fails): the province is then unknown.
  final ProvinceBoundaries? provinces;
  final VoidCallback? onOpenMap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Opens the SOS sheet at once; the sheet itself waits for GPS.
class _HomeScreenState extends State<HomeScreen> {
  // The hold and the screen-reader long-press can both confirm, so open only one sheet.
  bool _sosOpen = false;

  Future<void> _onSos() async {
    if (_sosOpen) return;
    _sosOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _SosSheet(location: widget.location),
      );
    } finally {
      _sosOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: LayoutBuilder(
        builder: (context, box) {
          // Large text takes the short layout too: a pinned bar plus a big slab would leave
          // little room to read.
          final tall =
              box.maxHeight >= AppSize.sosHeightTallScreen &&
              context.textScale < AppSize.compactTextScale;
          final sos = ContentWidth(
            child: SosBar(
              onConfirmed: _onSos,
              busy: false,
              height: tall ? AppSize.sosHeight : AppSize.sosHeightCompact,
              hint: context.tr(
                th: 'กดค้าง 1.5 วินาทีเพื่อส่งตำแหน่ง',
                en: 'Hold 1.5 seconds to share your location',
              ),
              semanticLabel: context.tr(th: 'SOS ฉุกเฉิน', en: 'SOS emergency'),
              semanticHint: context.tr(
                th: 'กดค้าง 1.5 วินาทีเพื่อส่งตำแหน่งของคุณ',
                en: 'Press and hold for 1.5 seconds to send your location',
              ),
            ),
          );
          final head = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: ContentWidth(
              child: _Head(storage: widget.storage, compact: !tall),
            ),
          );
          final slab = ContentWidth(
            child: _Slab(
              sensors: widget.sensors,
              alerts: widget.alerts,
              storage: widget.storage,
              provinces: widget.provinces,
              compact: !tall,
            ),
          );
          final sections = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: ContentWidth(
              child: _Board(
                alerts: widget.alerts,
                storage: widget.storage,
                provinces: widget.provinces,
                onOpenMap: widget.onOpenMap,
              ),
            ),
          );
          // A short, wide screen (landscape phone) keeps the SOS bar in its own column so the
          // level gets the full height.
          final sideBySide = !tall && box.maxWidth >= AppSize.wideBreakpoint;
          // SOS is always on screen. A tall screen scrolls the slab away and pins the bar under
          // the status bar; a short one fixes the bar at the top and scrolls everything else.
          return SafeArea(
            bottom: false,
            child: sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [head, slab, sections],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: AppSize.sidePanelWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpace.md,
                            top: AppSpace.sm,
                          ),
                          child: sos,
                        ),
                      ),
                    ],
                  )
                : tall
                ? CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: head),
                      SliverToBoxAdapter(child: slab),
                      // The gap keeps a red danger slab apart from the red SOS bar.
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpace.md),
                      ),
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          color: t.ground,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.sm),
                            child: sos,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: sections),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sos,
                      const SizedBox(height: AppSpace.xs),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [head, slab, sections],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

// The level Home shows: the sensors' level and the official alert for the last known area,
// whichever is worse. fromOfficial says the official alert decided it.
({AlertLevel? level, bool fromOfficial}) homeLevel(
  SensorService sensors,
  AlertService? alerts,
  StorageService storage, {
  ProvinceBoundaries? provinces,
}) {
  final LatLng? p = storage.lastPosition;
  final official = alerts != null && alerts.hasSnapshot && p != null
      ? alerts.levelAt(p, provinceCode: provinces?.codeAt(p))
      : null;
  final level = AlertRules.combine(sensors.level, official);
  final fromOfficial =
      level != null && level == official && level != sensors.level;
  return (level: level, fromOfficial: fromOfficial);
}

// Where the level applies: whether the phone has a last known position.
String _areaText(BuildContext context, StorageService storage) =>
    storage.lastPosition == null
    ? context.tr(th: 'ยังไม่ทราบพื้นที่', en: 'Area not known yet')
    : context.tr(th: 'พื้นที่ตำแหน่งล่าสุดของคุณ', en: 'Your last known area');

// The screen title with the settings gear, the "Water level" header and the area line.
class _Head extends StatelessWidget {
  const _Head({required this.storage, required this.compact});

  final StorageService storage;

  // Short screens and large text: smaller title, and the area shares the header's row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final header = Semantics(
      header: true,
      child: Text(
        context.tr(th: 'ระดับน้ำ', en: 'Water level'),
        style: text.titleMedium,
      ),
    );
    // The slab speaks the area too, so this copy is for the eyes only.
    final area = ExcludeSemantics(
      child: ListenableBuilder(
        listenable: storage,
        builder: (context, _) => Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place, size: AppIconSize.sm, color: t.mark),
            const SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text(
                _areaText(context, storage),
                style: text.bodySmall?.copyWith(color: t.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenTitle(
          context.tr(th: 'แจ้งภัยและช่วยเหลือ', en: 'Disaster Alert'),
          trailing: SettingsButton(storage: storage),
          compact: compact,
        ),
        if (compact)
          // One row when it fits, wrapped when it does not.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.md,
              children: [header, area],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: header,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpace.xs,
              bottom: AppSpace.sm,
            ),
            child: area,
          ),
        ],
      ],
    );
  }
}

// The water-level slab: the tier's gauge, icon, step and word (never color alone), the advice
// and where the level came from, one source per line. No data is neutral: never Safe.
class _Slab extends StatelessWidget {
  const _Slab({
    required this.sensors,
    required this.storage,
    this.alerts,
    this.provinces,
    this.compact = false,
  });

  final SensorService sensors;
  final StorageService storage;
  final AlertService? alerts;
  final ProvinceBoundaries? provinces;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sensors, ?alerts, storage]),
      builder: (context, _) {
        final (:level, :fromOfficial) = homeLevel(
          sensors,
          alerts,
          storage,
          provinces: provinces,
        );
        final at = sensors.fetchedAt;
        final List<String> sources;
        if (fromOfficial) {
          sources = [
            context.tr(
              th: 'ประกาศเตือนภัยทางการ ในพื้นที่ล่าสุดของคุณ',
              en: 'Official alert for your last known area',
            ),
          ];
        } else if (sensors.isDemo) {
          sources = [
            context.tr(
              th: 'ข้อมูลทดลอง ไม่ใช่ค่าจริง',
              en: 'Demo data, not real',
            ),
          ];
        } else if (!sensors.isLive) {
          sources = [
            context.tr(
              th: 'ยังไม่ได้เชื่อมต่อเซนเซอร์',
              en: 'Not connected to sensors yet',
            ),
          ];
        } else if (at == null) {
          sources = [
            context.tr(
              th: 'เชื่อมต่อเซนเซอร์ไม่ได้',
              en: 'Cannot reach the sensors',
            ),
          ];
        } else {
          sources = [
            // DRAFT (Phase R, owner to approve Thai): the old one-line "From community sensors ·
            // updated …" is now two lines; the " · " is gone and English "updated" is "Updated".
            context.tr(th: 'จากเซนเซอร์ชุมชน', en: 'From community sensors'),
            context.tr(
              th:
                  'อัปเดต ${context.stamp(at)}'
                  '${sensors.isStale ? ' (ข้อมูลอาจเก่า)' : ''}',
              en:
                  'Updated ${context.stamp(at)}'
                  '${sensors.isStale ? ' (may be out of date)' : ''}',
            ),
          ];
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
        // The last line of the slab. Never a bare time for data that is not live.
        final posted = sensors.isDemo
            ? context.tr(
                th: 'ทดลอง ${context.clock(sensors.latest.time)}',
                en: 'Demo ${context.clock(sensors.latest.time)}',
              )
            : at == null
            ? context.tr(th: 'ไม่มีข้อมูลสด', en: 'No live data')
            : context.stamp(at);
        return LevelSlab(
          level: level,
          label: label,
          step: step,
          advice: advice,
          sources: sources,
          posted: posted,
          area: _areaText(context, storage),
          compact: compact,
        );
      },
    );
  }
}

// The ruled sections: quick calls, nearest shelter and official notices.
class _Board extends StatelessWidget {
  const _Board({
    required this.storage,
    this.alerts,
    this.provinces,
    this.onOpenMap,
  });

  final StorageService storage;
  final AlertService? alerts;
  final ProvinceBoundaries? provinces;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _QuickCalls(),
          _NearestShelter(storage: storage, onOpenMap: onOpenMap),
          if (alerts != null)
            _OfficialAlerts(
              alerts: alerts!,
              storage: storage,
              provinces: provinces,
            ),
        ],
      ),
    );
  }
}

// One ruled row per emergency number; a tap opens the dialer (as on the Call tab).
class _QuickCalls extends StatelessWidget {
  const _QuickCalls();

  @override
  Widget build(BuildContext context) {
    return Section(
      title: context.tr(th: 'โทรด่วน', en: 'Quick call'),
      children: [
        for (final n in EmergencyNumbers.sos)
          RuledRow(
            icon: emergencyIcon(n),
            title: n.number,
            subtitle: context.serviceName(n),
            trailing: const Icon(Icons.call),
            semanticLabel: context.tr(
              th: 'โทร ${n.number} ${context.serviceName(n)}',
              en: 'Call ${n.number}, ${context.serviceName(n)}',
            ),
            onTap: () => EmergencyLauncher.call(n.number),
          ),
      ],
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
        final sample = MockData.isDemoShelterList(shelters);
        final title = from == null
            ? context.tr(th: 'ศูนย์พักพิง', en: 'Shelters')
            : context.tr(th: 'ศูนย์พักพิงใกล้สุด', en: 'Nearest shelter');
        final children = <Widget>[
          if (sample)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Tag(
                  context.tr(th: 'ตัวอย่าง', en: 'Sample'),
                  icon: Icons.science_outlined,
                ),
              ),
            ),
          if (sample)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                context.tr(
                  th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                  en: 'Sample, not real shelters',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ];
        if (from == null) {
          children.add(
            RuledRow(
              icon: Icons.home_work,
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
            ),
          );
        } else {
          final s = Nearby.sorted(shelters, from).first;
          children.add(
            RuledRow(
              icon: Icons.home_work,
              title: context.shelterName(s),
              subtitle: s.capacity == null
                  ? null
                  : context.shelterCapacity(s.capacity!),
              trailing: Tag(
                context.distance(Nearby.metersTo(from, s)),
                icon: Icons.near_me,
              ),
            ),
          );
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: FilledButton.icon(
                onPressed: () => EmergencyLauncher.navigate(s.lat, s.lng),
                icon: const Icon(Icons.directions),
                label: Text(
                  context.tr(th: 'นำทางไปที่นี่', en: 'Get directions'),
                ),
              ),
            ),
          );
        }
        return Section(title: title, children: children);
      },
    );
  }
}

// Official notices with level, sender and time. With no backend yet it says so plainly instead
// of showing an invented warning.
class _OfficialAlerts extends StatelessWidget {
  const _OfficialAlerts({
    required this.alerts,
    required this.storage,
    this.provinces,
  });

  final AlertService alerts;
  final StorageService storage;
  final ProvinceBoundaries? provinces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return ListenableBuilder(
      listenable: Listenable.merge([alerts, storage]),
      builder: (context, _) {
        final at = alerts.fetchedAt;
        final children = <Widget>[];
        if (at == null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: WarningBanner(
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
            ),
          );
        } else {
          final shown = alerts.visibleAlerts;
          if (alerts.isStale) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: WarningBanner(
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
              ),
            );
          }
          if (shown.isEmpty && !alerts.isStale) {
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Text(
                  context.tr(
                    th: 'ไม่มีประกาศเตือนภัยในพื้นที่ · ตรวจล่าสุด ${context.stamp(at)}',
                    en: 'No alerts for your area · checked ${context.stamp(at)}',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }
          // Same inputs as the level above, so a notice tagged "in your area" is the one that
          // raised the level. Yours first, unknown next, other areas last; nothing is hidden.
          final point = storage.lastPosition;
          final code = point == null ? null : provinces?.codeAt(point);
          final ranked =
              [
                for (final (n, a) in shown.indexed)
                  (n, a, AlertRules.areaOf(a, point, code)),
              ]..sort((x, y) {
                final byArea = x.$3.index.compareTo(y.$3.index);
                return byArea != 0 ? byArea : x.$1.compareTo(y.$1);
              });
          for (final (_, a, area) in ranked) {
            final style = t.styleFor(a.level);
            final tag = _areaTag(context, area);
            final headline =
                a.headline[context.isThai ? 'th' : 'en'] ??
                a.headline['th'] ??
                context.levelLabel(a.level);
            children.add(
              RuledRow(
                // Opens the full notice (min 48 dp tall).
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlertDetailScreen(
                      alert: a,
                      alerts: alerts,
                      provinces: provinces,
                    ),
                  ),
                ),
                title: headline,
                subtitle: '${a.sender} · ${context.stamp(a.sent)}',
                semanticLabel:
                    '${context.levelLabel(a.level)}. $headline. '
                    '${a.sender}, ${context.stamp(a.sent)}. ${tag.word}',
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tag(
                      context.levelLabel(a.level),
                      icon: style.icon,
                      color: style.color,
                      onColor: style.onColor,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Tag(
                      tag.word,
                      icon: tag.icon,
                      color: tag.color,
                      onColor: tag.onColor,
                    ),
                  ],
                ),
              ),
            );
          }
        }
        children.add(
          RuledRow(
            // Past notices only; opens the record (min 48 dp tall).
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AlertHistoryScreen(alerts: alerts, provinces: provinces),
              ),
            ),
            icon: Icons.history,
            // DRAFT wording, owner to approve.
            title: context.tr(th: 'ประวัติประกาศ', en: 'Alert history'),
          ),
        );
        return Section(
          title: context.tr(th: 'ประกาศทางการ', en: 'Official notices'),
          children: children,
        );
      },
    );
  }
}

// Icon, word and color of a notice's area tag; the word and icon carry the meaning, the color
// only backs them up.
({String word, IconData icon, Color? color, Color? onColor}) _areaTag(
  BuildContext context,
  AlertArea area,
) {
  final t = context.tokens;
  return switch (area) {
    AlertArea.inYourArea => (
      // DRAFT wording, owner to approve.
      word: context.tr(th: 'ในพื้นที่ของคุณ', en: 'In your area'),
      icon: Icons.place,
      color: null,
      onColor: null,
    ),
    AlertArea.otherAreas => (
      // DRAFT wording, owner to approve.
      word: context.tr(th: 'พื้นที่อื่น', en: 'Other areas'),
      icon: Icons.public,
      color: t.ground,
      onColor: t.inkMuted,
    ),
    AlertArea.unknown => (
      // DRAFT wording, owner to approve.
      word: context.tr(th: 'ไม่ทราบพื้นที่', en: 'Area unknown'),
      icon: Icons.location_off,
      color: t.offlineBg,
      onColor: t.ink,
    ),
  };
}

// What opens after a confirmed SOS: calling comes first, the ready-made message second. The
// call buttons never wait for GPS; the position and then the address fill in when they arrive.
class _SosSheet extends StatefulWidget {
  const _SosSheet({required this.location});

  final LocationService location;

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  // Null while GPS is still being read.
  LocationResult? _result;
  // Null until the address lookup answers; the message shows '-' meanwhile.
  Place? _place;
  // Set once when the position arrives so later rebuilds never change the time line.
  DateTime? _at;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final r = await widget.location.getCurrent();
    if (!mounted) return;
    setState(() {
      _result = r;
      _at = DateTime.now();
    });
    final point = r.point;
    if (point == null) return;
    Place place;
    try {
      place = await widget.location.describe(point);
    } catch (_) {
      place = const Place();
    }
    if (!mounted) return;
    setState(() => _place = place);
  }

  // The message carries both languages because the person reading it may speak either.
  String _message(BuildContext context, LatLng point, bool fromCache) {
    final where = _place == null ? '' : context.placeText(_place!);
    final lat = point.latitude.toStringAsFixed(6);
    final lng = point.longitude.toStringAsFixed(6);
    // Local time plus the UTC offset, so a rescuer in another zone reads the right hour.
    final now = _at!;
    final off = now.timeZoneOffset;
    final hh = off.inHours.abs().toString().padLeft(2, '0');
    final mm = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final time =
        '${now.toString().substring(0, 16)} UTC${off.isNegative ? '-' : '+'}$hh:$mm';
    final cached = fromCache
        ? ' (ตำแหน่งที่บันทึกไว้ล่าสุด / last saved position)'
        : '';
    return 'SOS! ต้องการความช่วยเหลือ / I need help.\n'
        'ที่อยู่ / Address: ${where.isEmpty ? '-' : where}$cached\n'
        'แผนที่ / Map: https://www.google.com/maps?q=$lat,$lng\n'
        'เวลา / Time: $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final result = _result;
    final locating = result == null;
    final reason = (result == null || result.issue == null)
        ? ''
        : context.locationError(result.issue!);
    final fromCache = result?.fromCache ?? false;
    final point = result?.point;
    final text = point == null ? null : _message(context, point, fromCache);
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
            (text == null && !locating)
                ? context.tr(
                    th: 'หาตำแหน่งของคุณไม่ได้',
                    en: 'Cannot find your location',
                  )
                : context.tr(th: 'ขอความช่วยเหลือ', en: 'Ask for help'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpace.md),
          if (text == null && !locating)
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
          if (locating) ...[
            SectionLabel(
              context.tr(th: 'ส่งตำแหน่งของคุณ', en: 'Send your location'),
            ),
            // Neutral, not red: waiting for GPS is a normal state.
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const SizedBox(
                    width: AppIconSize.sm,
                    height: AppIconSize.sm,
                    child: CircularProgressIndicator(
                      strokeWidth: AppStroke.frame,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Icon(Icons.my_location, color: t.ink),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      // DRAFT (same words as the SOS button's busy hint)
                      context.tr(
                        th: 'กำลังหาตำแหน่งของคุณ…',
                        en: 'Finding your location…',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: t.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
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
