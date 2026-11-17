import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../models/shelter.dart';
import '../services/emergency_launcher.dart';
import '../services/nearby.dart';
import '../services/offline_map.dart';
import '../services/offline_map_theme.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/notice.dart';
import '../widgets/sensor_readings.dart';
import '../widgets/warning_banner.dart';
import 'settings_screen.dart';

// Map: the offline Protomaps map (OpenStreetMap data) with shelter, sensor and "you" markers.
// Phones get the shelter list as a sheet over the map; wide screens get it as a side column.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.storage,
    required this.sensors,
    this.loadMap = loadBundledBangkokMap,
  });

  final StorageService storage;
  final SensorService sensors;
  final OfflineMapLoader loadMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Holds the map controller and the loading of the offline map file.
class _MapScreenState extends State<MapScreen> {
  static const double _focusZoom = 16;
  static const double _startZoom = 15;
  // Share of the map the shelter sheet covers when the tab opens.
  static const double _sheetStart = 0.4;

  final MapController _mapController = MapController();
  late Future<_MapSource> _tiles = _open();
  Object? _loadError;

  // Which list the sheet shows: shelters (default) or the sensor readings.
  bool _showSensors = false;

  // The map area's height when the camera last fitted the markers; a change (the offline notice
  // appearing, rotation) fits them again so none sits clipped at an edge.
  double? _fittedHeight;

  // Opens the map file, plus the icons: a missing icon sheet only costs the icons, not the map.
  Future<_MapSource> _open() async {
    final tiles = await widget.loadMap();
    SpriteStyle? sprites;
    try {
      sprites = await loadMapSprites();
    } catch (_) {}
    return _MapSource(tiles, sprites);
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
            Text(s.name, style: Theme.of(sheet).textTheme.headlineSmall),
            const SizedBox(height: AppSpace.xs),
            Text(
              [
                context.shelterCapacity(s.capacity),
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
            const SizedBox(height: AppSpace.sm),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                _mapController.move(LatLng(s.lat, s.lng), _focusZoom);
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
    _tiles = _open();
  });

  // Back to the user's last position, or the area centre when it is unknown.
  void _recenter() => _mapController.move(
    widget.storage.lastPosition ?? MockData.areaCenter,
    _startZoom,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) {
        final from = widget.storage.lastPosition;
        final shelters = Nearby.sorted(widget.storage.shelters, from);
        final wide = MediaQuery.sizeOf(context).width >= AppSize.wideBreakpoint;
        final header = ScreenHeader(
          title: context.tr(th: 'แผนที่', en: 'Map'),
          trailing: SettingsButton(storage: widget.storage),
        );
        if (wide) {
          return SafeArea(
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
                        width: AppSize.sidePanelWidth,
                        decoration: BoxDecoration(
                          color: t.ground,
                          border: Border(
                            left: BorderSide(
                              color: t.ink,
                              width: AppStroke.heavy,
                            ),
                          ),
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
                      builder: (context, controller) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.ground,
                          border: Border(
                            top: BorderSide(
                              color: t.ink,
                              width: AppStroke.heavy,
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
  // shelters are framed squares, sensor stations ink discs.
  Marker _marker({
    required LatLng point,
    required String label,
    required IconData icon,
    required bool square,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return Marker(
      point: point,
      width: AppSize.tapTarget,
      height: AppSize.tapTarget,
      child: Semantics(
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
              decoration: BoxDecoration(
                color: square ? t.surface : t.ink,
                shape: square ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(
                  color: square ? t.ink : t.surface,
                  width: AppStroke.frame,
                ),
              ),
              child: Icon(
                icon,
                color: square ? t.ink : t.surface,
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
        final fit = CameraFit.coordinates(
          coordinates: [
            for (final s in shelters) LatLng(s.lat, s.lng),
            for (final st in MockData.stations) LatLng(st.lat, st.lng),
            ?from,
          ],
          maxZoom: _focusZoom,
          padding: EdgeInsets.fromLTRB(
            AppSize.tapTarget,
            AppSize.tapTarget + AppSpace.md,
            AppSize.tapTarget + AppSpace.md,
            box.maxHeight * sheet + AppSize.tapTarget,
          ),
        );
        final first = _fittedHeight == null;
        if (_fittedHeight != box.maxHeight) {
          _fittedHeight = box.maxHeight;
          if (!first) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.fitCamera(fit);
            });
          }
        }
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
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: MockData.areaCenter,
                      initialZoom: _startZoom,
                      initialCameraFit: fit,
                      backgroundColor: t.offlineBg,
                    ),
                    children: [
                      // The map picture comes from a file on the phone, so it works with no signal.
                      FutureBuilder<_MapSource>(
                        key: ValueKey(_tiles),
                        future: _tiles,
                        builder: (context, snap) {
                          if (snap.hasError && _loadError == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _loadError = snap.error);
                              }
                            });
                          }
                          final source = snap.data;
                          if (source == null) return const SizedBox.shrink();
                          return VectorTileLayer(
                            theme: offlineMapTheme,
                            sprites: source.sprites,
                            // 512 px tiles drawn from one zoom level up: a quarter of the tiles (and
                            // label layouts) per screen, which is what keeps dragging smooth.
                            tileOffset: TileOffset.mapbox,
                            tileProviders: TileProviders({
                              'protomaps': source.tiles,
                            }),
                            // One tile drawn at a time, so a drag never stacks several 40 ms tiles
                            // into one long frame.
                            concurrency: 1,
                            // Tiles are already local: a second cache copy would only waste storage.
                            fileCacheTtl: Duration.zero,
                            // Bigger memory caches so panning back over seen tiles does not redraw them.
                            memoryTileCacheMaxSize: 50 * 1024 * 1024,
                            memoryTileDataCacheMaxSize: 80,
                            textCacheMaxSize: 600,
                          );
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          for (final s in shelters)
                            _marker(
                              point: LatLng(s.lat, s.lng),
                              label: '$shelterWord: ${s.name}',
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
                              onTap: () =>
                                  _showName('$stationWord: ${st.name}'),
                            ),
                          if (from != null)
                            Marker(
                              point: from,
                              width: AppIconSize.lg,
                              height: AppIconSize.lg,
                              child: Semantics(
                                label: context.tr(
                                  th: 'ตำแหน่งล่าสุดของคุณ',
                                  en: 'Your last known position',
                                ),
                                child: _YouAreHere(tokens: t),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpace.sm,
              top: AppSpace.sm,
              child: Material(
                color: t.surface,
                shape: RoundedRectangleBorder(side: t.frame),
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
                  color: t.ground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: AppStroke.frame,
                  ),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // The calm notice above the map when the map file cannot be opened. On very short screens it
  // scrolls inside a third of the height rather than pushing the map away.
  Widget _offlineNotice() {
    if (_loadError == null) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.3,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.sm),
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

  // The sheet: a Shelters | Sensors switch, then the shelter list (nearest first when the position is known), or an empty state.
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.lg,
      ),
      children: [
        if (sheet)
          Center(
            child: Container(
              width: AppSize.tapTarget,
              height: AppStroke.heavy + AppStroke.rule,
              margin: const EdgeInsets.only(bottom: AppSpace.sm),
              color: t.ink,
            ),
          ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.home_work),
              label: Text(context.tr(th: 'ศูนย์พักพิง', en: 'Shelters')),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.sensors),
              label: Text(context.tr(th: 'เซนเซอร์', en: 'Sensors')),
            ),
          ],
          selected: {_showSensors},
          onSelectionChanged: (v) => setState(() => _showSensors = v.first),
        ),
        const SizedBox(height: AppSpace.md),
        if (_showSensors)
          SensorReadings(sensors: widget.sensors)
        else ...[
          Text(
            context.tr(
              th: 'ศูนย์พักพิง (${shelters.length})',
              en: 'Shelters (${shelters.length})',
            ),
            style: theme.textTheme.titleMedium,
          ),
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
                child: NoticeTag(
                  context.tr(
                    th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                    en: 'Sample, not real shelters',
                  ),
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
              _LegendMark(tokens: t, square: true, icon: Icons.home_work),
              Text(
                context.tr(th: 'ศูนย์พักพิง', en: 'Shelter'),
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(width: AppSpace.sm),
              _LegendMark(tokens: t, square: false, icon: Icons.sensors),
              Text(
                context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station'),
                style: theme.textTheme.labelMedium,
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
            ),
          for (final (i, s) in shelters.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: NoticeTile(
                onTap: () => _showShelter(s),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home_work),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i == 0 && from != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.xs,
                              ),
                              child: NoticeTag(
                                context.tr(th: 'ใกล้สุด', en: 'Nearest'),
                              ),
                            ),
                          Text(s.name, style: theme.textTheme.titleSmall),
                          Text(
                            [
                              if (from != null)
                                context.distance(Nearby.metersTo(from, s)),
                              context.shelterCapacity(s.capacity),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// A small copy of a map marker for the legend.
class _LegendMark extends StatelessWidget {
  const _LegendMark({
    required this.tokens,
    required this.square,
    required this.icon,
  });

  final AppTokens tokens;
  final bool square;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: AppIconSize.lg,
        height: AppIconSize.lg,
        decoration: BoxDecoration(
          color: square ? tokens.surface : tokens.ink,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          border: Border.all(
            color: square ? tokens.ink : tokens.surface,
            width: AppStroke.frame,
          ),
        ),
        child: Icon(
          icon,
          size: AppIconSize.sm - AppSpace.xs,
          color: square ? tokens.ink : tokens.surface,
        ),
      ),
    );
  }
}

// "You are here": a small ink dot inside a paper ring and an outer ink ring, so it reads apart
// from the square shelters and the large sensor discs. Red stays reserved for danger.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.ink, width: AppStroke.frame),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm - AppStroke.frame),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tokens.ink, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// The opened map file and its icons.
class _MapSource {
  const _MapSource(this.tiles, this.sprites);

  final VectorTileProvider tiles;
  final SpriteStyle? sprites;
}
