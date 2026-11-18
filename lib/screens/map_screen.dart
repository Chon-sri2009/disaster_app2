import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:maplibre/maplibre.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../models/shelter.dart';
import '../services/emergency_launcher.dart';
import '../services/nearby.dart';
import '../services/offline_map.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/desktop_vector_map.dart';
import '../widgets/soft_ui.dart';
import '../widgets/sensor_readings.dart';
import '../widgets/warning_banner.dart';
import 'settings_screen.dart';

// Map: the offline Protomaps map, drawn by MapLibre on the GPU, (OpenStreetMap data) with shelter, sensor and "you" markers.
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
  // MapLibre counts zoom on 512 px tiles, one level below the 256 px scale older maps used.
  static const double _focusZoom = 15;
  static const double _startZoom = 14;
  // Share of the map the shelter sheet covers when the tab opens.
  static const double _sheetStart = 0.4;

  MapController? _mapController;
  // Desktop builds draw the same map with flutter_map; this drives its camera.
  final _desktopController = fm.MapController();
  bool _desktopReady = false;
  late Future<String> _tiles = widget.loadMap();
  Object? _loadError;

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
            Text(s.name, style: Theme.of(sheet).textTheme.headlineSmall),
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
    _tiles = widget.loadMap();
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
        final header = BrandHeader(
          title: context.tr(th: 'แผนที่', en: 'Map'),
          trailing: SettingsButton(storage: widget.storage),
        );
        // The header band paints behind the status bar, so the top is not inset.
        if (wide) {
          return SafeArea(
            top: false,
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
          top: false,
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
                      builder: (context, controller) => Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.ground,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.xl),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.ink.withValues(alpha: 0.18),
                              blurRadius: 16,
                            ),
                          ],
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
  // shelters are brand-filled rounded squares, sensor stations white discs with a brand ring.
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
                shape: const CircleBorder(),
                elevation: AppElevation.overlay,
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
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: const BorderRadiusDirectional.only(
                      bottomEnd: Radius.circular(AppRadius.sm),
                    ).resolve(Directionality.of(context)),
                  ),
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
              width: AppSize.dragHandle.width,
              height: AppSize.dragHandle.height,
              margin: const EdgeInsets.only(bottom: AppSpace.md),
              decoration: BoxDecoration(
                color: t.inkMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
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
                child: StatusPill(
                  context.tr(
                    th: 'ตัวอย่าง ไม่ใช่ศูนย์พักพิงจริง',
                    en: 'Sample, not real shelters',
                  ),
                  icon: Icons.science_outlined,
                  color: t.offlineBg,
                  onColor: t.ink,
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
              child: SoftTile(
                onTap: () => _showShelter(s),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppSize.tapTarget,
                      height: AppSize.tapTarget,
                      decoration: BoxDecoration(
                        color: t.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.home_work, color: t.brand),
                    ),
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
                              child: StatusPill(
                                context.tr(th: 'ใกล้สุด', en: 'Nearest'),
                              ),
                            ),
                          Text(s.name, style: theme.textTheme.titleSmall),
                          Text(
                            [
                              if (from != null)
                                context.distance(Nearby.metersTo(from, s)),
                              if (s.capacity != null)
                                context.shelterCapacity(s.capacity!),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// The marker shapes, shared by the map and its legend.
BoxDecoration _markerDecoration(AppTokens t, bool square) => BoxDecoration(
  color: square ? t.brand : t.surface,
  shape: square ? BoxShape.rectangle : BoxShape.circle,
  borderRadius: square ? BorderRadius.circular(AppRadius.sm) : null,
  border: Border.all(
    color: square ? t.surface : t.brand,
    width: AppStroke.frame,
  ),
  boxShadow: t.cardShadow,
);

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

// "You are here": a brand dot in a white ring on a soft brand halo, so it reads apart from the
// square shelters and the larger sensor discs. Red stays reserved for danger.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.brand.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xs + AppStroke.frame),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.surface, width: AppStroke.accent),
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
