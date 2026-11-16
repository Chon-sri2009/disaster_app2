import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../data/mock_data.dart';
import '../l10n/l10n.dart';
import '../models/shelter.dart';
import '../services/emergency_launcher.dart';
import '../services/offline_map.dart';
import '../services/offline_map_theme.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/warning_banner.dart';

// Map screen: offline Protomaps map (OpenStreetMap data) with shelter and sensor markers, plus a shelter list.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.storage,
    this.loadMap = loadBundledBangkokMap,
  });

  final StorageService storage;
  final OfflineMapLoader loadMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Holds the map controller and the loading of the offline map file.
class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late Future<_MapSource> _tiles = _open();
  Object? _loadError;

  // Opens the map file, plus the icons: a missing icon sheet only costs the icons, not the map.
  Future<_MapSource> _open() async {
    final tiles = await widget.loadMap();
    SpriteStyle? sprites;
    try {
      sprites = await loadMapSprites();
    } catch (_) {}
    return _MapSource(tiles, sprites);
  }

  // Shows the name of a tapped marker in a snack bar.
  void _showName(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(name)));
  }

  // Straight-line distance from the last saved GPS position, or null when there is none.
  double? _metersTo(Shelter s) {
    final from = widget.storage.lastPosition;
    if (from == null) return null;
    return const Distance()(from, LatLng(s.lat, s.lng));
  }

  String _distanceText(double meters) => meters < 1000
      ? context.tr(
          th: '${(meters / 10).round() * 10} ม.',
          en: '${(meters / 10).round() * 10} m',
        )
      : context.tr(
          th: '${(meters / 1000).toStringAsFixed(1)} กม.',
          en: '${(meters / 1000).toStringAsFixed(1)} km',
        );

  // Shelter details with the two things people need: where it is and how to get there.
  void _showShelter(Shelter s) {
    final meters = _metersTo(s);
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
                context.tr(
                  th: 'รองรับได้ประมาณ ${s.capacity} คน',
                  en: 'Holds about ${s.capacity} people',
                ),
                if (meters != null)
                  context.tr(
                    th: 'ห่างจากคุณ ${_distanceText(meters)}',
                    en: '${_distanceText(meters)} from you',
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
                _mapController.move(LatLng(s.lat, s.lng), 16);
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

  // Builds a map marker with a 48 dp tap area, a screen-reader label and an icon.
  Marker _marker(
    double lat,
    double lng,
    String name,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Marker(
      point: LatLng(lat, lng),
      width: AppSize.tapTarget,
      height: AppSize.tapTarget,
      child: Semantics(
        button: true,
        label: name,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: context.tokens.surface, width: 2),
              ),
              child: Icon(icon, color: context.tokens.surface, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.storage,
        builder: (context, _) {
          final shelters = widget.storage.shelters;
          final map = _buildMap(shelters, t);
          final list = _buildList(shelters);
          final wide =
              MediaQuery.sizeOf(context).width >= AppSize.wideBreakpoint;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 3, child: map),
                VerticalDivider(width: 1, color: t.hairline),
                Expanded(flex: 2, child: list),
              ],
            );
          }
          return Column(
            children: [
              Expanded(flex: 3, child: map),
              Divider(color: t.hairline),
              Expanded(flex: 2, child: list),
            ],
          );
        },
      ),
    );
  }

  // The map with an offline banner on top when tiles cannot load.
  Widget _buildMap(List<Shelter> shelters, AppTokens t) {
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          if (_loadError != null)
            // Natural height, but never more than 45% of the area: it scrolls on very short screens.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
              child: SingleChildScrollView(
                child: Padding(
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
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: MockData.areaCenter,
                initialZoom: 15,
              ),
              children: [
                // The map picture comes from a file on the phone, so it works with no signal.
                FutureBuilder<_MapSource>(
                  key: ValueKey(_tiles),
                  future: _tiles,
                  builder: (context, snap) {
                    if (snap.hasError && _loadError == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _loadError = snap.error);
                      });
                    }
                    final source = snap.data;
                    if (source == null) return const SizedBox.shrink();
                    final provider = source.tiles;
                    final sprites = source.sprites;
                    return VectorTileLayer(
                      theme: offlineMapTheme,
                      sprites: sprites,
                      // 512 px tiles drawn from one zoom level up: a quarter of the tiles (and
                      // label layouts) per screen, which is what keeps dragging smooth.
                      tileOffset: TileOffset.mapbox,
                      tileProviders: TileProviders({'protomaps': provider}),
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
                        s.lat,
                        s.lng,
                        '${context.tr(th: 'ศูนย์พักพิง', en: 'Shelter')}: ${s.name}',
                        Icons.home_work,
                        t.accent,
                        () => _showShelter(s),
                      ),
                    for (final st in MockData.stations)
                      _marker(
                        st.lat,
                        st.lng,
                        '${context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station')}: ${st.name}',
                        Icons.sensors,
                        t.ink,
                        () => _showName(
                          '${context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station')}: ${st.name}',
                        ),
                      ),
                  ],
                ),
                // The credit line is legal text, not content: keep it one line at any text scale.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: SimpleAttributionWidget(
                    source: Text(
                      'OpenStreetMap contributors',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Legend: what the two marker icons mean (also readable by screen readers).
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.md,
              children: [
                Icon(Icons.home_work, color: t.accent, size: 24),
                Text(context.tr(th: 'ศูนย์พักพิง', en: 'Shelter')),
                Icon(Icons.sensors, color: t.ink, size: 24),
                Text(context.tr(th: 'สถานีเซนเซอร์', en: 'Sensor station')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nearest first when a position is known, otherwise the saved order.
  List<Shelter> _nearestFirst(List<Shelter> shelters) {
    if (widget.storage.lastPosition == null) return shelters;
    return [...shelters]
      ..sort((a, b) => _metersTo(a)!.compareTo(_metersTo(b)!));
  }

  // The shelter list, or an empty state when nothing is cached yet.
  Widget _buildList(List<Shelter> shelters) {
    final theme = Theme.of(context);
    if (shelters.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.md),
        child: WarningBanner(
          message: context.tr(
            th:
                'ยังไม่มีรายชื่อศูนย์พักพิงในเครื่อง '
                'เปิดแอปตอนมีอินเทอร์เน็ตสักครั้งเพื่อดาวน์โหลด',
            en:
                'No shelters are saved on this phone yet. '
                'Open the app once with internet to download the list.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(
            context.tr(
              th: 'ศูนย์พักพิง (${shelters.length})',
              en: 'Shelters (${shelters.length})',
            ),
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final s in _nearestFirst(shelters))
          ListTile(
            minVerticalPadding: AppSpace.sm,
            leading: Icon(Icons.home_work, color: context.tokens.accent),
            title: Text(s.name, style: theme.textTheme.titleSmall),
            subtitle: Text(
              [
                context.tr(
                  th: 'รองรับได้ประมาณ ${s.capacity} คน',
                  en: 'Holds about ${s.capacity} people',
                ),
                if (_metersTo(s) != null) _distanceText(_metersTo(s)!),
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showShelter(s),
          ),
      ],
    );
  }
}

// The opened map file and its icons.
class _MapSource {
  const _MapSource(this.tiles, this.sprites);

  final VectorTileProvider tiles;
  final SpriteStyle? sprites;
}
