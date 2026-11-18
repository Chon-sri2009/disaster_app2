import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/bangkok_shelters.dart';
import 'data/mock_data.dart';
import 'l10n/l10n.dart';
import 'screens/calls_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'services/alert_service.dart';
import 'services/flood_history_service.dart';
import 'services/location_service.dart';
import 'services/offline_map.dart';
import 'services/province_locator.dart';
import 'services/sensor_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/soft_ui.dart';

// Starts the app: opens local storage, caches the shelter list, then shows the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  // Stand-in for "download shelters when online". Seed only an empty cache: a real
  // downloaded list must survive a restart.
  // The bundled list also replaces the sample list and any older copy of itself; a list
  // downloaded later (with other ids) is left alone.
  final bundled = {for (final s in bangkokShelters) s.id};
  if (storage.shelters.every(
    (s) => bundled.contains(s.id) || MockData.shelters.any((m) => m.id == s.id),
  )) {
    await storage.saveShelters(bangkokShelters);
  }
  runApp(DisasterApp(storage: storage));
}

// The root widget: day and night boards (following the phone) and the main shell.
class DisasterApp extends StatelessWidget {
  const DisasterApp({
    super.key,
    required this.storage,
    this.loadMap = loadBundledBangkokMap,
  });

  final StorageService storage;
  final OfflineMapLoader loadMap;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the language changes; AppShell keeps its state because its type is unchanged.
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => context.tr(
          th: 'แจ้งภัยและช่วยเหลือ',
          en: 'Disaster Alert & Rescue',
        ),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: storage.themeMode,
        locale: Locale(storage.language.code),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _MapGate(storage: storage, loadMap: loadMap),
      ),
    );
  }
}

// Shows a loading screen while the map pack is prepared (the first launch copies it into the
// app's folder), then opens the app with the ready map. If preparing fails, the app still opens
// and the Map tab shows its own "try again" banner.
class _MapGate extends StatefulWidget {
  const _MapGate({required this.storage, required this.loadMap});

  final StorageService storage;
  final OfflineMapLoader loadMap;

  @override
  State<_MapGate> createState() => _MapGateState();
}

class _MapGateState extends State<_MapGate> {
  late final Future<String> _ready = widget.loadMap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _StartupNotice();
        }
        final style = snap.data;
        return AppShell(
          storage: widget.storage,
          loadMap: style == null ? widget.loadMap : () async => style,
        );
      },
    );
  }
}

// Holds the services and the navigation that switches between the 5 tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.storage, required this.loadMap});

  final StorageService storage;
  final OfflineMapLoader loadMap;

  @override
  State<AppShell> createState() => _AppShellState();
}

// Creates the services once and keeps the selected tab.
class _AppShellState extends State<AppShell> {
  // Set at build time: --dart-define=SENSOR_SNAPSHOT_URL=https://host/snapshot and
  // --dart-define=ALERT_SNAPSHOT_URL=https://host/alerts
  late final SensorService _sensors = SensorService(
    snapshotUrl: const String.fromEnvironment('SENSOR_SNAPSHOT_URL'),
  );
  late final FloodHistoryService _flood = FloodHistoryService(
    snapshotUrl: const String.fromEnvironment('SENSOR_SNAPSHOT_URL'),
  );
  late final AlertService _alerts =
      AlertService(
          widget.storage,
          snapshotUrl: const String.fromEnvironment('ALERT_SNAPSHOT_URL'),
        )
        ..refresh()
        ..startAutoRefresh();
  late final LocationService _location = LocationService(widget.storage);
  // Read in the background; Home treats the province as unknown until it arrives (or if it
  // fails), so this never gates the app or the map.
  late final Future<ProvinceBoundaries> _provinces = ProvinceBoundaries.load();
  int _index = 0;

  // Call sits in the middle as a filled brand circle: the most urgent tab after SOS.
  List<(Widget, Widget, String)> _destinations(
    BuildContext context, {
    required bool rail,
  }) => [
    (
      const Icon(Icons.home_outlined),
      const Icon(Icons.home),
      context.tr(th: 'หน้าแรก', en: 'Home'),
    ),
    (
      const Icon(Icons.map_outlined),
      const Icon(Icons.map),
      context.tr(th: 'แผนที่', en: 'Map'),
    ),
    (
      _RaisedCall(lifted: !rail),
      _RaisedCall(lifted: !rail),
      context.tr(th: 'โทร', en: 'Call'),
    ),
    (
      const Icon(Icons.edit_note_outlined),
      const Icon(Icons.edit_note),
      context.tr(th: 'รายงาน', en: 'Report'),
    ),
    (
      const Icon(Icons.menu_book_outlined),
      const Icon(Icons.menu_book),
      context.tr(th: 'คู่มือ', en: 'Guide'),
    ),
  ];

  static const _mapTab = 1;

  @override
  void dispose() {
    _sensors.dispose();
    _alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // A rail needs room for five labeled items, so short landscape phones keep the bottom bar.
    final wide =
        size.width >= AppSize.wideBreakpoint &&
        size.height >= AppSize.railMinHeight;
    final destinations = _destinations(context, rail: wide);
    // IndexedStack keeps every screen alive, so form text and map position are not lost.
    final body = IndexedStack(
      index: _index,
      children: [
        FutureBuilder<ProvinceBoundaries>(
          future: _provinces,
          builder: (context, snap) => HomeScreen(
            sensors: _sensors,
            location: _location,
            alerts: _alerts,
            storage: widget.storage,
            provinces: snap.data,
            onOpenMap: () => setState(() => _index = _mapTab),
          ),
        ),
        MapScreen(
          storage: widget.storage,
          sensors: _sensors,
          floodHistory: _flood,
          loadMap: widget.loadMap,
        ),
        CallsScreen(storage: widget.storage),
        ReportScreen(storage: widget.storage, location: _location),
        GuideScreen(storage: widget.storage),
      ],
    );

    if (wide) {
      // Tablet or landscape phone: a navigation rail on the side saves vertical space.
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: d.$1,
                      selectedIcon: d.$2,
                      label: Text(d.$3),
                    ),
                ],
              ),
            ),
            VerticalDivider(color: context.tokens.hairline),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      // A white bar lifted off the canvas by a soft shadow (a hairline at night).
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: context.tokens.cardShadow.isEmpty
              ? Border(top: BorderSide(color: context.tokens.hairline))
              : null,
          boxShadow: context.tokens.cardShadow,
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.$1,
                selectedIcon: d.$2,
                label: d.$3,
              ),
          ],
        ),
      ),
    );
  }
}

// The first-launch screen while the map pack is copied: the app's name on a soft card.
class _StartupNotice extends StatelessWidget {
  const _StartupNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.noticeMaxWidth,
              ),
              child: SoftCard(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr(
                        th: 'แจ้งภัยและช่วยเหลือ',
                        en: 'Disaster Alert & Rescue',
                      ),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpace.md),
                    const LinearProgressIndicator(minHeight: AppSpace.sm),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      context.tr(
                        th: 'กำลังเตรียมแผนที่ออฟไลน์…',
                        en: 'Preparing the offline map…',
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The Call tab's icon: a filled brand circle, so the emergency dialer stands out. In the bottom
// bar it keeps the icon's 24 dp layout box (its label lines up with the others) and is drawn
// larger and lifted; the rail has room for the full circle in place.
class _RaisedCall extends StatelessWidget {
  const _RaisedCall({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final circle = Container(
      width: AppSize.raisedNavIcon,
      height: AppSize.raisedNavIcon,
      decoration: BoxDecoration(
        color: t.brand,
        shape: BoxShape.circle,
        boxShadow: t.cardShadow,
      ),
      child: Icon(Icons.call, color: t.onBrand, size: AppIconSize.md),
    );
    if (!lifted) return circle;
    return SizedBox.square(
      dimension: AppIconSize.md,
      child: OverflowBox(
        maxWidth: AppSize.raisedNavIcon,
        maxHeight: AppSize.raisedNavIcon,
        child: Transform.translate(
          offset: const Offset(0, -AppSpace.sm),
          child: circle,
        ),
      ),
    );
  }
}
