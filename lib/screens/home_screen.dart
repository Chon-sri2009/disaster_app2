import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/emergency_numbers.dart';
import '../data/mock_data.dart';
import '../services/alert_service.dart';
import '../services/emergency_launcher.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/sos_hold_button.dart';
import '../widgets/warning_banner.dart';

// Home screen: alert level, water level, latest warning, and a pinned press-and-hold SOS button.
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

    final danger = context.tokens.danger;
    final point = result.point;
    if (point == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.location_off, color: danger, size: 32),
          title: const Text('Cannot find your location'),
          content: Text(
            '${result.error}\n\nNo saved position is available. '
            'Call your local emergency number if you are in danger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final lat = point.latitude.toStringAsFixed(6);
    final lng = point.longitude.toStringAsFixed(6);
    final time = DateTime.now().toString().substring(0, 16);
    final source = result.fromCache ? ' (last saved position)' : '';
    final message =
        'SOS! I need help.\n'
        'Location: $lat, $lng$source\n'
        'Map: https://www.google.com/maps?q=$lat,$lng\n'
        'Time: $time';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.sos, color: danger, size: 32),
        title: const Text('Your help message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.fromCache)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: WarningBanner(
                    kind: BannerKind.error,
                    message:
                        'GPS failed (${result.error}) so the last saved position is used.',
                  ),
                ),
              SelectableText(message),
              const SizedBox(height: AppSpace.md),
              Text(
                'Emergency calls: ${EmergencyNumbers.sos.map((n) => '${n.number} ${n.service}').join(', ')}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          for (final n in EmergencyNumbers.sos)
            TextButton.icon(
              onPressed: () => EmergencyLauncher.call(n.number),
              icon: const Icon(Icons.call),
              label: Text('Call ${n.number}'),
            ),
          TextButton.icon(
            onPressed: () => EmergencyLauncher.sms(const [], message),
            icon: const Icon(Icons.sms),
            label: const Text('SMS'),
          ),
          FilledButton.icon(
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: message)),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
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

// The scrolling part of Home: level band, water meter and the latest warning.
class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.sensors, this.alerts});

  final SensorService sensors;
  final AlertService? alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LevelBand(sensors: sensors),
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (alerts != null) _OfficialAlerts(alerts: alerts!),
              // The warning comes first: it is the next thing to read after the level.
              const WarningBanner(message: MockData.latestWarning),
              const SizedBox(height: AppSpace.md),
              _WaterMeter(sensors: sensors),
            ],
          ),
        ),
      ],
    );
  }
}

// A full-width colored band with the alert level as icon + word + advice (never color alone).
class _LevelBand extends StatelessWidget {
  const _LevelBand({required this.sensors});

  final SensorService sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: sensors,
      builder: (context, _) {
        final level = sensors.level;
        final style = context.tokens.styleFor(level);
        final onColor = style.onColor;
        return Semantics(
          container: true,
          liveRegion: true,
          label:
              'Alert level for ${MockData.areaName}: ${level.label}. ${level.advice}',
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              color: style.color,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(style.icon, size: 56, color: onColor),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MockData.areaName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onColor,
                              ),
                            ),
                            Text(
                              level.label,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: onColor,
                              ),
                            ),
                            Text(
                              level.advice,
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
        final time = reading.time.toString().substring(11, 19);
        return Semantics(
          container: true,
          label:
              'Water level ${reading.waterCm.toStringAsFixed(0)} centimeters, '
              'safe limit ${MockData.waterLimitCm.toStringAsFixed(0)} centimeters'
              '${over ? ', over the limit' : ''}',
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
                        'Water level',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${reading.waterCm.toStringAsFixed(0)} cm',
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
                  'Safe limit ${MockData.waterLimitCm.toStringAsFixed(0)} cm · '
                  'mock data, updated $time',
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
                ? 'Finding your location…'
                : 'Hold 1.5 seconds to share your location',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// Official alerts with their age. Shows nothing until a snapshot has loaded.
class _OfficialAlerts extends StatelessWidget {
  const _OfficialAlerts({required this.alerts});

  final AlertService alerts;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: alerts,
      builder: (context, _) {
        final at = alerts.fetchedAt;
        if (at == null) return const SizedBox.shrink();
        final local = at.toLocal();
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (alerts.isStale)
                WarningBanner(
                  kind: BannerKind.offline,
                  message:
                      'Alerts last updated $hh:$mm. They may be out of date.',
                ),
              for (final a in alerts.visibleAlerts)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: WarningBanner(
                    message:
                        '${a.level.label} (${a.sender}): ${a.headline['th'] ?? a.headline.values.first}',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
