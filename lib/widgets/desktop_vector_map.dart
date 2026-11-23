import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show SpriteIndexReader;

import '../services/offline_map_theme.dart';

// The offline map on Windows, macOS and Linux, where the MapLibre plugin has no build. It reads
// the same style file offline_map.dart writes (so the same bundled pack and icons) and draws it
// with flutter_map. Nothing here touches the network.
class DesktopVectorMap extends StatefulWidget {
  const DesktopVectorMap({
    super.key,
    required this.styleFile,
    required this.controller,
    required this.center,
    required this.zoom,
    required this.background,
    required this.onReady,
    required this.markers,
    required this.thai,
  });

  final String styleFile;
  final MapController controller;
  final LatLng center;
  final double zoom;
  final Color background;
  final VoidCallback onReady;
  final List<Marker> markers;
  final bool thai;

  @override
  State<DesktopVectorMap> createState() => _DesktopVectorMapState();
}

class _Source {
  const _Source(this.tiles, this.sprites);

  final VectorTileProvider tiles;
  final SpriteStyle sprites;
}

class _DesktopVectorMapState extends State<DesktopVectorMap> {
  late final Future<_Source> _source = _open(widget.styleFile);
  // The tuned Protomaps layers as a theme for the desktop renderer, labelled in the app language.
  late final _theme = const ProtomapsThemes().build(
    offlineMapLayers(thai: widget.thai),
  );

  static Future<_Source> _open(String styleFile) async {
    final style = jsonDecode(
      await File(styleFile).readAsString(),
    ) as Map<String, dynamic>;
    // The style points at the pack as pmtiles://file:///...; the provider wants the plain path.
    final url = (style['sources'] as Map)['protomaps']['url'] as String;
    final pack = Uri.parse(url.substring('pmtiles://'.length)).toFilePath();
    final dir = File(styleFile).parent.path;
    final sprites = SpriteStyle(
      atlasProvider: () => File('$dir/sprites.png').readAsBytes(),
      index: SpriteIndexReader().read(
        jsonDecode(await File('$dir/sprites.json').readAsString())
            as Map<String, dynamic>,
      ),
    );
    return _Source(await PmTilesVectorTileProvider.fromSource(pack), sprites);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Source>(
      future: _source,
      builder: (context, snap) {
        final source = snap.data;
        return FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            backgroundColor: widget.background,
            onMapReady: widget.onReady,
          ),
          children: [
            if (source != null)
              VectorTileLayer(
                theme: _theme,
                sprites: source.sprites,
                tileOffset: TileOffset.mapbox,
                tileProviders: TileProviders({'protomaps': source.tiles}),
                concurrency: 1,
                fileCacheTtl: Duration.zero,
              ),
            MarkerLayer(markers: widget.markers),
          ],
        );
      },
    );
  }
}
