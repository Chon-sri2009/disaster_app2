import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'data/mock_data.dart';
import 'l10n/l10n.dart';
import 'screens/calls_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'services/alert_service.dart';
import 'services/location_service.dart';
import 'services/offline_map.dart';
import 'services/sensor_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/notice.dart';

// Starts the app: opens local storage, caches the shelter list, then shows the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  // Stand-in for "download shelters when online". Seed only an empty cache: a real
  // downloaded list must survive a restart.
  if (storage.shelters.isEmpty) await storage.saveShelters(MockData.shelters);
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
  late final Future<VectorTileProvider> _ready = widget.loadMap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VectorTileProvider>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _StartupNotice();
        }
        final provider = snap.data;
        return AppShell(
          storage: widget.storage,
          loadMap: provider == null ? widget.loadMap : () async => provider,
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
  // Set at build time: --dart-define=SENSOR_SNAPSHOT_URL=https://host/snapshot
  late final SensorService _sensors = SensorService(
    snapshotUrl: const String.fromEnvironment('SENSOR_SNAPSHOT_URL'),
  );
  late final AlertService _alerts = AlertService(widget.storage)..refresh();
  late final LocationService _location = LocationService(widget.storage);
  int _index = 0;

  List<(IconData, IconData, String)> _destinations(BuildContext context) => [
    (Icons.home_outlined, Icons.home, context.tr(th: 'หน้าแรก', en: 'Home')),
    (Icons.call_outlined, Icons.call, context.tr(th: 'โทร', en: 'Call')),
    (Icons.map_outlined, Icons.map, context.tr(th: 'แผนที่', en: 'Map')),
    (
      Icons.edit_note_outlined,
      Icons.edit_note,
      context.tr(th: 'รายงาน', en: 'Report'),
    ),
    (
      Icons.menu_book_outlined,
      Icons.menu_book,
      context.tr(th: 'คู่มือ', en: 'Guide'),
    ),
  ];

  static const _mapTab = 2;

  @override
  void dispose() {
    _sensors.dispose();
    _alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final size = MediaQuery.sizeOf(context);
    // A rail needs room for five labeled items, so short landscape phones keep the bottom bar.
    final wide =
        size.width >= AppSize.wideBreakpoint &&
        size.height >= AppSize.railMinHeight;
    // IndexedStack keeps every screen alive, so form text and map position are not lost.
    final body = IndexedStack(
      index: _index,
      children: [
        HomeScreen(
          sensors: _sensors,
          location: _location,
          alerts: _alerts,
          storage: widget.storage,
          onOpenMap: () => setState(() => _index = _mapTab),
        ),
        CallsScreen(storage: widget.storage),
        MapScreen(
          storage: widget.storage,
          sensors: _sensors,
          loadMap: widget.loadMap,
        ),
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
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
            ),
            VerticalDivider(
              width: AppStroke.heavy,
              thickness: AppStroke.heavy,
              color: context.tokens.ink,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      // The tab bar is ruled off from the board like the foot of a notice.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.tokens.ink, width: AppStroke.heavy),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: d.$3,
              ),
          ],
        ),
      ),
    );
  }
}

// The first-launch screen while the map pack is copied: the app's name on a framed notice.
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
              child: NoticeFrame(
                borderWidth: AppStroke.heavy,
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
                    const LinearProgressIndicator(
                      minHeight: AppStroke.heavy * 2,
                    ),
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
