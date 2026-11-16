import 'package:flutter/material.dart';

import 'data/mock_data.dart';
import 'screens/guide_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'screens/sensors_screen.dart';
import 'services/alert_service.dart';
import 'services/location_service.dart';
import 'services/offline_map.dart';
import 'services/sensor_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

// Starts the app: opens local storage, caches the shelter list, then shows the UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  // Stand-in for "download shelters when online"; real data would be saved here.
  await storage.saveShelters(MockData.shelters);
  runApp(DisasterApp(storage: storage));
}

// The root widget: the light theme and the main shell.
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
    return MaterialApp(
      title: 'Disaster Alert & Rescue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AppShell(storage: storage, loadMap: loadMap),
    );
  }
}

// Holds the services and the navigation that switches between the 5 screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.storage, required this.loadMap});

  final StorageService storage;
  final OfflineMapLoader loadMap;

  @override
  State<AppShell> createState() => _AppShellState();
}

// Creates the services once and keeps the selected tab.
class _AppShellState extends State<AppShell> {
  late final SensorService _sensors = SensorService();
  late final AlertService _alerts = AlertService(widget.storage)..refresh();
  late final LocationService _location = LocationService(widget.storage);
  int _index = 0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.sensors_outlined, Icons.sensors, 'Sensors'),
    (Icons.map_outlined, Icons.map, 'Map'),
    (Icons.edit_note_outlined, Icons.edit_note, 'Report'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Guide'),
  ];

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
    // IndexedStack keeps every screen alive, so form text and map position are not lost.
    final body = IndexedStack(
      index: _index,
      children: [
        HomeScreen(sensors: _sensors, location: _location, alerts: _alerts),
        SensorsScreen(sensors: _sensors),
        MapScreen(storage: widget.storage, loadMap: widget.loadMap),
        ReportScreen(storage: widget.storage, location: _location),
        const GuideScreen(),
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
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: context.tokens.hairline),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
