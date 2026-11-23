import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:maplibre/maplibre.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../models/shelter.dart';
import '../services/emergency_launcher.dart';
import '../services/flood_history_service.dart';
import '../services/nearby.dart';
import '../services/offline_map.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/desktop_vector_map.dart';
import '../widgets/notice_ui.dart';
import '../widgets/sensor_readings.dart';
import '../widgets/warning_banner.dart';
import 'flood_history_card.dart';
import 'settings_screen.dart';

// Map: the offline Protomaps map, drawn by MapLibre on the GPU, (OpenStreetMap data) with shelter, sensor and "you" markers.
// Phones get the shelter list as a sheet over the map; wide screens get it as a side column.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.storage,
    required this.sensors,
    this.floodHistory,
    this.loadMap = loadBundledBangkokMap,
  });

  final StorageService storage;
  final SensorService sensors;
  final FloodHistoryService? floodHistory;
  final OfflineMapLoader loadMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Holds the map controller and the loading of the offline map file.
class _MapScreenState extends State<MapScreen> {
  // MapLibre counts zoom on 512 px tiles, one level below the 256 px scale older maps used.
  static const double _focusZoom = 15;
  static const double _startZoom = 14;
  // Share of the map the shelter sheet covers when the tab opens.
  static const double _sheetStart = 0.4;

  MapController? _mapController;
  // Desktop builds draw the same map with flutter_map; this drives its camera.
  final _desktopController = fm.MapController();
  bool _desktopReady = false;
  // The map file is opened per app language (labels follow it), so it is set up in
  // didChangeDependencies and reopened when the language changes.
  late Future<String> _tiles;
  bool? _tilesThai;
  Object? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final thai = context.isThai;
    if (_tilesThai == thai) return;
    _tilesThai = thai;
    _tiles = widget.loadMap(thai: thai);
  }

  // Which list the sheet shows: shelters (default) or the sensor readings.
  bool _showSensors = false;

  // The map area's height when the camera last fitted the markers; a change (the offline notice
  // appearing, rotation) fits them again so none sits clipped at an edge.
  double? _fittedHeight;

  // Where the camera should fit the markers, kept from the latest layout so it can be applied as
  // soon as the map exists and again when the map area changes size.
  List<Geographic> _fitPoints = const [];
  EdgeInsets _fitPadding = EdgeInsets.zero;

  void _fitMarkers() {
    if (_useDesktopMap) {
      if (!_desktopReady || _fitPoints.isEmpty) return;
      _desktopController.fitCamera(
        fm.CameraFit.bounds(
          bounds: fm.LatLngBounds.fromPoints([
            for (final g in _fitPoints) LatLng(g.lat, g.lon),
          ]),
          padding: _fitPadding,
          maxZoom: _startZoom + _desktopZoomShift,
        ),
      );
      return;
    }
    _mapController?.fitBounds(
      bounds: LngLatBounds.fromPoints(_fitPoints),
      padding: _fitPadding,
      nativeDuration: Duration.zero,
    );
  }

  // Shows the name of a tapped sensor marker in a snack bar.
  void _showName(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(name)));
  }

  // Shelter details with the two things people need: where it is and how to get there.
  void _showShelter(Shelter s) {
    final from = widget.storage.lastPosition;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheet.shelterName(s),
              style: Theme.of(sheet).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              [
                if (s.capacity != null) context.shelterCapacity(s.capacity!),
                if (from != null)
                  context.tr(
                    th: 'ห่างจากคุณ ${context.distance(Nearby.metersTo(from, s))}',
                    en: '${context.distance(Nearby.metersTo(from, s))} from you',
                  ),
              ].join(' · '),
              style: Theme.of(sheet).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: () => EmergencyLauncher.navigate(s.lat, s.lng),
              icon: const Icon(Icons.directions),
              label: Text(
                context.tr(th: 'นำทางไปที่นี่', en: 'Get directions'),
              ),
            ),
            if (s.phone != null) ...[
              const SizedBox(height: AppSpace.sm),
              OutlinedButton.icon(
                onPressed: () => EmergencyLauncher.call(s.phone!),
                icon: const Icon(Icons.call),
                label: Text(s.phone!),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                _moveTo(LatLng(s.lat, s.lng));
              },
              icon: const Icon(Icons.my_location),
              label: Text(context.tr(th: 'ดูบนแผนที่', en: 'Show on map')),
            ),
          ],
        ),
      ),
    );
  }

  // Tries to open the map file again after a failure.
  void _retryTiles() => setState(() {
    _loadError = null;
    _tiles = widget.loadMap(thai: context.isThai);
  });

  // Back to the user's last position, or the area centre when it is unknown.
  void _recenter() => _moveTo(
    widget.storage.lastPosition ?? MockData.areaCenter,
    zoom: _startZoom,
  );

  void _moveTo(LatLng p, {double zoom = _focusZoom}) {
    if (_useDesktopMap) {
      if (_desktopReady) _desktopController.move(p, zoom + _desktopZoomShift);
      return;
    }
    _mapController?.animateCamera(
      center: Geographic(lon: p.longitude, lat: p.latitude),
      zoom: zoom,
      nativeDuration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) {
        final from = widget.storage.lastPosition;
        final shelters = Nearby.sorted(widget.storage.shelters, from);
        final wide = MediaQuery.sizeOf(context).width >= AppSize.wideBreakpoint;
        // The title sits on the ground, so the status bar is inset; the nav bar is the Scaffold's.
        final header = Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: ScreenTitle(
            context.tr(th: 'แผนที่', en: 'Map'),
            compact: true,
            trailing: SettingsButton(storage: widget.storage),
          ),
        );
        if (wide) {
          return SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                _offlineNotice(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildMap(shelters, from, t, sheet: 0)),
                      Container(
                        key: const ValueKey('map-side-column'),
                        width: AppSize.sidePanelWidth,
                        decoration: BoxDecoration(
                          color: t.ground,
                          border: Border(left: BorderSide(color: t.hairline)),
                        ),
                        child: _buildList(shelters, from, null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              _offlineNotice(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildMap(shelters, from, t, sheet: _sheetStart),
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: _sheetStart,
                      minChildSize: 0.2,
                      maxChildSize: 0.92,
                      snap: true,
                      // A plain sheet: square top edge under a rule, no shadow.
                      builder: (context, controller) => Container(
                        key: const ValueKey('map-sheet'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.ground,
                          border: Border(
                            top: BorderSide(
                              color: t.mark,
                              width: AppStroke.frame,
                            ),
                          ),
                        ),
                        child: _buildList(shelters, from, controller),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Builds a map marker with a 48 dp tap area, a screen-reader label and a shape per kind:
  // shelters are brand-filled squares, sensor stations white discs with a brand ring.
  _Pin _marker({
    required LatLng point,
    required String label,
    required IconData icon,
    required bool square,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return _Pin(
      point,
      AppSize.tapTarget,
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: AppSize.marker,
              height: AppSize.marker,
              decoration: _markerDecoration(t, square),
              child: Icon(
                icon,
                color: square ? t.onBrand : t.brand,
                size: AppIconSize.sm,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The map, with the offline notice, legend, credit and recenter control laid over it.
  // `sheet` is the share of the map hidden under the shelter sheet, so the first view fits every
  // marker into the part that stays visible, clear of the legend and the edges.
  Widget _buildMap(
    List<Shelter> shelters,
    LatLng? from,
    AppTokens t, {
    required double sheet,
  }) {
    final theme = Theme.of(context);
    final shelterWord = context.tr(th: 'ศูนย์พักพิง', en: 'Shelter');
    final stationWord = context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station');
    return LayoutBuilder(
      builder: (context, box) {
        _fitPoints = [
          for (final s in shelters) Geographic(lon: s.lng, lat: s.lat),
          for (final st in MockData.stations)
            Geographic(lon: st.lng, lat: st.lat),
          if (from != null) Geographic(lon: from.longitude, lat: from.latitude),
        ];
        _fitPadding = EdgeInsets.fromLTRB(
          AppSize.tapTarget,
          AppSize.tapTarget + AppSpace.md,
          AppSize.tapTarget + AppSpace.md,
          box.maxHeight * sheet + AppSize.tapTarget,
        );
        if (_fittedHeight != null && _fittedHeight != box.maxHeight) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitMarkers();
          });
        }
        _fittedHeight = box.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: context.tr(
                  th: 'แผนที่ศูนย์พักพิงและสถานีเซนเซอร์',
                  en: 'Map of shelters and sensor stations',
                ),
                child: ColoredBox(
                  color: t.offlineBg,
                  child: FutureBuilder<String>(
                    key: ValueKey(_tiles),
                    future: _tiles,
                    builder: (context, snap) {
                      if (snap.hasError && _loadError == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _loadError = snap.error);
                        });
                      }
                      final style = snap.data;
                      if (style == null) return const SizedBox.expand();
                      final pins = [
                        for (final s in shelters)
                          _marker(
                            point: LatLng(s.lat, s.lng),
                            label: '$shelterWord: ${context.shelterName(s)}',
                            icon: Icons.home_work,
                            square: true,
                            onTap: () => _showShelter(s),
                          ),
                        for (final st in MockData.stations)
                          _marker(
                            point: LatLng(st.lat, st.lng),
                            label: '$stationWord: ${st.name}',
                            icon: Icons.sensors,
                            square: false,
                            onTap: () => _showName('$stationWord: ${st.name}'),
                          ),
                        if (from != null)
                          _Pin(
                            from,
                            AppIconSize.lg,
                            Semantics(
                              label: context.tr(
                                th: 'ตำแหน่งล่าสุดของคุณ',
                                en: 'Your last known position',
                              ),
                              child: _YouAreHere(tokens: t),
                            ),
                          ),
                      ];
                      if (_useDesktopMap) {
                        // Desktop builds: the same pack and style, drawn by flutter_map.
                        return DesktopVectorMap(
                          key: ValueKey(style),
                          thai: context.isThai,
                          styleFile: style,
                          controller: _desktopController,
                          center: MockData.areaCenter,
                          zoom: _startZoom + _desktopZoomShift,
                          background: t.offlineBg,
                          onReady: () {
                            _desktopReady = true;
                            _fitMarkers();
                          },
                          markers: [
                            for (final p in pins)
                              fm.Marker(
                                point: p.point,
                                width: p.size,
                                height: p.size,
                                child: p.child,
                              ),
                          ],
                        );
                      }
                      if (!_mapSupported) return _unsupportedPlatform(t);
                      // The map is drawn by the phone's GPU from files on the phone, so it
                      // works with no signal and drags without waiting on Dart.
                      return MapLibreMap(
                        options: MapOptions(
                          initStyle: style,
                          initCenter: Geographic(
                            lon: MockData.areaCenter.longitude,
                            lat: MockData.areaCenter.latitude,
                          ),
                          initZoom: _startZoom,
                          maxPitch: 0,
                        ),
                        onEvent: (event) {
                          if (event is MapEventMapCreated) {
                            _mapController = event.mapController;
                            _fitMarkers();
                          }
                        },
                        children: [
                          WidgetLayer(
                            markers: [
                              for (final p in pins)
                                Marker(
                                  point: Geographic(
                                    lon: p.point.longitude,
                                    lat: p.point.latitude,
                                  ),
                                  size: Size.square(p.size),
                                  child: p.child,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpace.sm,
              top: AppSpace.sm,
              child: Material(
                color: t.surface,
                elevation: AppElevation.none,
                shape: Border.all(color: t.mark, width: AppStroke.frame),
                child: IconButton(
                  tooltip: context.tr(
                    th: 'กลับไปที่ตำแหน่งของคุณ',
                    en: 'Back to your position',
                  ),
                  onPressed: _recenter,
                  icon: const Icon(Icons.my_location),
                ),
              ),
            ),
            // The credit line is legal text, not content: keep it one line at any text scale.
            Positioned(
              left: 0,
              top: 0,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.0,
                child: Container(
                  color: t.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: AppStroke.frame,
                  ),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: theme.textTheme.labelSmall?.copyWith(color: t.ink),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // MapLibre draws on phones and the web only; Windows, macOS and Linux builds use flutter_map
  // over the same bundled pack (DesktopVectorMap), so the map is there when testing on a PC.
  static bool get _mapSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _useDesktopMap =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // flutter_map counts zoom on 256 px tiles, one level above MapLibre's 512 px scale.
  static const double _desktopZoomShift = 1;

  Widget _unsupportedPlatform(AppTokens t) => ColoredBox(
    color: t.offlineBg,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Text(
          context.tr(
            th: 'แผนที่แสดงบนมือถือ (Android / iPhone) เท่านั้น',
            en: 'The map is drawn on phones (Android / iPhone) only.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  // The calm notice above the map when the map file cannot be opened. On very short screens it
  // scrolls inside a third of the height rather than pushing the map away.
  Widget _offlineNotice() {
    if (_loadError == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.3,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          AppSpace.sm,
        ),
        child: WarningBanner(
          kind: BannerKind.offline,
          message: context.tr(
            th: 'เปิดแผนที่ออฟไลน์ไม่ได้ แต่ยังดูหมุดและรายชื่อศูนย์พักพิงได้',
            en:
                'The offline map could not be opened. '
                'Markers and the shelter list still work.',
          ),
          actionLabel: context.tr(th: 'ลองอีกครั้ง', en: 'Try again'),
          onAction: _retryTiles,
        ),
      ),
    );
  }

  // The sheet: a Shelters | Sensors pair of text tabs, then the shelter list (nearest first when
  // the position is known) or an empty state. On a phone the sheet drags, so it keeps a handle in
  // a 48 dp grab area; the wide side column has none.
  Widget _buildList(
    List<Shelter> shelters,
    LatLng? from,
    ScrollController? controller,
  ) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final sheet = controller != null;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      children: [
        if (sheet)
          SizedBox(
            key: const ValueKey('map-sheet-grab'),
            height: AppSize.tapTarget,
            child: Center(
              child: Container(
                width: AppSize.dragHandle.width,
                height: AppSize.dragHandle.height,
                color: t.mark,
              ),
            ),
          )
        else
          const SizedBox(height: AppSpace.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IntrinsicHeight: both tabs take the taller one's height when a Thai label wraps.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SheetTab(
                        key: const ValueKey('map-tab-shelters'),
                        label: context.tr(th: 'ศูนย์พักพิง', en: 'Shelters'),
                        selected: !_showSensors,
                        onTap: () => setState(() => _showSensors = false),
                      ),
                    ),
                    Expanded(
                      child: _SheetTab(
                        key: const ValueKey('map-tab-sensors'),
                        label: context.tr(th: 'เซนเซอร์', en: 'Sensors'),
                        selected: _showSensors,
                        onTap: () => setState(() => _showSensors = true),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: AppStroke.rule, color: t.hairline),
              if (widget.floodHistory != null)
                FloodHistoryCard(
                  service: widget.floodHistory!,
                  storage: widget.storage,
                ),
              if (_showSensors) ...[
                const SizedBox(height: AppSpace.md),
                SensorReadings(sensors: widget.sensors),
              ] else
                Section(
                  title: context.tr(
                    th: 'ศูนย์พักพิง (${shelters.length})',
                    en: 'Shelters (${shelters.length})',
                  ),
                  children: [
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      from == null
                          ? context.tr(
                              th: 'ยังไม่ทราบตำแหน่งของคุณ จึงเรียงตามที่บันทึกไว้',
                              en: 'Your position is not known, so these are in saved order.',
                            )
                          : context.tr(
                              th: 'เรียงจากใกล้คุณที่สุด',
                              en: 'Nearest to you first',
                            ),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (MockData.isDemoShelterList(shelters))
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Tag(
                            context.tr(
                              th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                              en: 'Sample, not real shelters',
                            ),
                            icon: Icons.science_outlined,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.sm),
                    // Legend: the two marker shapes, drawn as they appear on the map.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.xs,
                      children: [
                        _legendItem(
                          _LegendMark(
                            markKey: const ValueKey('legend-shelter'),
                            tokens: t,
                            square: true,
                            icon: Icons.home_work,
                          ),
                          context.tr(th: 'ศูนย์พักพิง', en: 'Shelter'),
                        ),
                        _legendItem(
                          _LegendMark(
                            markKey: const ValueKey('legend-station'),
                            tokens: t,
                            square: false,
                            icon: Icons.sensors,
                          ),
                          context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (shelters.isEmpty)
                      WarningBanner(
                        message: context.tr(
                          th:
                              'ยังไม่มีรายชื่อศูนย์พักพิงในเครื่อง '
                              'เปิดแอปตอนมีอินเทอร์เน็ตสักครั้งเพื่อดาวน์โหลด',
                          en:
                              'No shelters are saved on this phone yet. '
                              'Open the app once with internet to download the list.',
                        ),
                      )
                    else
                      Container(height: AppStroke.rule, color: t.hairline),
                    for (final (i, s) in shelters.indexed)
                      _shelterRow(s, i, from),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // A legend entry kept together (mark and word), so a wrapped legend never splits them.
  Widget _legendItem(Widget mark, String word) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: AppSpace.xs),
      Flexible(
        child: Text(word, style: Theme.of(context).textTheme.labelMedium),
      ),
    ],
  );

  // One shelter: bare icon, name, distance and capacity; the nearest carries a tag with the word.
  Widget _shelterRow(Shelter s, int i, LatLng? from) {
    final t = context.tokens;
    final detail = [
      if (from != null) context.distance(Nearby.metersTo(from, s)),
      if (s.capacity != null) context.shelterCapacity(s.capacity!),
    ].join(' · ');
    return RuledRow(
      icon: Icons.home_work,
      title: context.shelterName(s),
      subtitle: detail.isEmpty ? null : detail,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i == 0 && from != null) ...[
            Flexible(
              child: Tag(context.tr(th: 'ใกล้สุด', en: 'Nearest')),
            ),
            const SizedBox(width: AppSpace.xs),
          ],
          Icon(Icons.chevron_right, color: t.inkMuted),
        ],
      ),
      onTap: () => _showShelter(s),
    );
  }
}

// One of the two sheet tabs: a word over a 3 dp rule that is brand-coloured on the selected tab.
// The selected tab is also bolder and spoken as selected, so it is never colour alone.
class _SheetTab extends StatelessWidget {
  const _SheetTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.titleSmall!;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: t.pressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.tapTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: text.copyWith(
                    color: selected ? t.ink : t.inkMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: AppStroke.tab,
                child: DecoratedBox(
                  key: const ValueKey('map-tab-rule'),
                  decoration: BoxDecoration(
                    color: selected ? t.brand : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The marker shapes, shared by the map and its legend.
// Flat: the edge colour keeps them readable on the map without a shadow.
BoxDecoration _markerDecoration(AppTokens t, bool square) => BoxDecoration(
  color: square ? t.brand : t.surface,
  shape: square ? BoxShape.rectangle : BoxShape.circle,
  border: Border.all(
    color: square ? t.surface : t.brand,
    width: AppStroke.frame,
  ),
);

// A small copy of a map marker for the legend.
class _LegendMark extends StatelessWidget {
  const _LegendMark({
    required this.tokens,
    required this.square,
    required this.icon,
    required this.markKey,
  });

  final Key markKey;
  final AppTokens tokens;
  final bool square;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: markKey,
        width: AppIconSize.lg,
        height: AppIconSize.lg,
        decoration: _markerDecoration(tokens, square),
        child: Icon(
          icon,
          size: AppIconSize.sm - AppSpace.xs,
          color: square ? tokens.onBrand : tokens.brand,
        ),
      ),
    );
  }
}

// "You are here": a brand dot inside a brand ring on a surface disc, so it reads apart from the
// square shelters and the sensor discs. Red stays reserved for danger.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.brand, width: AppStroke.frame),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xs + AppStroke.frame),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// A marker both renderers can place: where it is, its box size and what it shows.
class _Pin {
  const _Pin(this.point, this.size, this.child);

  final LatLng point;
  final double size;
  final Widget child;
}
