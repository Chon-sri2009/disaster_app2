import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../data/mock_data.dart';
import '../models/shelter.dart';
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
  ) {
    return Marker(
      point: LatLng(lat, lng),
      width: AppSize.tapTarget,
      height: AppSize.tapTarget,
      child: Semantics(
        button: true,
        label: name,
        excludeSemantics: true,
        onTap: () => _showName(name),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showName(name),
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
                    message:
                        'The offline map could not be opened. '
                        'Markers and the shelter list still work.',
                    actionLabel: 'Try again',
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
                        'Shelter: ${s.name}',
                        Icons.home_work,
                        t.accent,
                      ),
                    for (final st in MockData.stations)
                      _marker(
                        st.lat,
                        st.lng,
                        'Sensor station: ${st.name}',
                        Icons.sensors,
                        t.ink,
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
                const Text('Shelter'),
                Icon(Icons.sensors, color: t.ink, size: 24),
                const Text('Sensor station'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The shelter list, or an empty state when nothing is cached yet.
  Widget _buildList(List<Shelter> shelters) {
    final theme = Theme.of(context);
    if (shelters.isEmpty) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpace.md),
        child: WarningBanner(
          message:
              'No shelters are saved on this phone yet. '
              'Open the app once with internet to download the list.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(
            'Shelters (${shelters.length})',
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final s in shelters)
          ListTile(
            minVerticalPadding: AppSpace.sm,
            leading: Icon(Icons.home_work, color: context.tokens.accent),
            title: Text(s.name, style: theme.textTheme.titleSmall),
            subtitle: Text('Capacity: ${s.capacity} people'),
            trailing: const Icon(Icons.my_location),
            onTap: () => _mapController.move(LatLng(s.lat, s.lng), 16),
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
