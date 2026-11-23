import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final Future<String> _ready = widget.loadMap(
    thai: widget.storage.language.code == 'th',
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _StartupNotice();
        }
        return AppShell(storage: widget.storage, loadMap: widget.loadMap);
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

  // Five equal tabs; Call is an ordinary tab (no raised circle).
  List<(IconData, IconData, String)> _destinations(BuildContext context) => [
    (Icons.home_outlined, Icons.home, context.tr(th: 'หน้าแรก', en: 'Home')),
    (Icons.map_outlined, Icons.map, context.tr(th: 'แผนที่', en: 'Map')),
    (Icons.call_outlined, Icons.call, context.tr(th: 'โทร', en: 'Call')),
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
    final destinations = _destinations(context);
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
            AppNavRail(
              destinations: destinations,
              selectedIndex: _index,
              onSelected: (i) => setState(() => _index = i),
            ),
            VerticalDivider(color: context.tokens.hairline),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: AppNavBar(
        destinations: destinations,
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
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

// One tab: icon over label, ink when selected, muted otherwise. The selection is a rule in the
// brand colour (never colour alone: ink, weight and the filled icon change too). The rule is
// always laid out, transparent when unselected, so nothing shifts on tap.
class _NavTab extends StatefulWidget {
  const _NavTab({
    required this.index,
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.vertical,
  });

  final int index;
  final (IconData, IconData, String) destination;
  final bool selected;
  final VoidCallback onTap;
  // true = the rail: the rule runs down the leading edge instead of across the top.
  final bool vertical;

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _focused = false;

  // Enter and Space activate the focused tab (the InkWell is not itself focusable, see build).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final destination = widget.destination;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final vertical = widget.vertical;
    final t = context.tokens;
    final color = selected ? t.ink : t.inkMuted;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final rule = ColoredBox(
      key: ValueKey('nav-rule-$index'),
      color: selected ? t.brand : Colors.transparent,
    );
    // Semantics wrap the label text only (the icon is decoration): a tight node that contrast
    // checks read as text, not the rule or the hairline. No side padding: narrow tabs need every
    // dp so Thai words are not split mid-word.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? destination.$2 : destination.$1,
          size: AppIconSize.md,
          color: color,
        ),
        Semantics(
          button: true,
          selected: selected,
          label: destination.$3,
          excludeSemantics: true,
          onTap: onTap,
          child: Text(
            destination.$3,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: style,
          ),
        ),
      ],
    );
    // One focus stop per tab, owned here, not by the InkWell: includeSemantics false keeps the
    // single label node (button + selected + tap) as the only semantics node, and the outline is
    // drawn on top as a border with no fill, so text contrast under it is unchanged.
    return Focus(
      includeSemantics: false,
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        children: [
          // Not positioned: it sizes the Stack, so the rail's unbounded height still works.
          InkWell(
            key: ValueKey('nav-tab-$index'),
            excludeFromSemantics: true,
            canRequestFocus: false,
            onTap: onTap,
            child: _tabBody(t, content, rule, vertical),
          ),
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: ValueKey('nav-focus-$index'),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.ink, width: AppStroke.frame),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody(AppTokens t, Widget content, Widget rule, bool vertical) {
    return vertical
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSize.tapTarget + AppSpace.xl,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                content,
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: AppStroke.tab,
                  child: rule,
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppStroke.tab, child: rule),
              Expanded(child: Center(child: content)),
            ],
          );
  }
}

// The bottom bar: ground colour, a hairline on top, no shadow.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(IconData, IconData, String)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Container, not DecoratedBox: it pads for the hairline, so no tab paints under it.
    return Container(
      decoration: BoxDecoration(
        color: t.ground,
        border: Border(
          top: BorderSide(color: t.hairline, width: AppStroke.rule),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          // Two label lines at 1.5x fit in navBar; past that the bar grows with the text.
          height:
              AppSize.navBar *
              (context.textScale.clamp(
                    AppSize.navBarFitScale,
                    AppSize.navBarMaxScale,
                  ) /
                  AppSize.navBarFitScale),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavTab(
                    index: i,
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                    vertical: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The side rail for wide screens: same tabs, the rule on the leading edge.
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(IconData, IconData, String)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.tokens.ground,
      child: SafeArea(
        child: SizedBox(
          width: AppSize.navRail,
          // Scrolls instead of clipping if a short screen at large text cannot fit five tabs.
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavTab(
                    index: i,
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                    vertical: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
