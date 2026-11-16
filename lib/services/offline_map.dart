import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

// Loads the map tiles. Replaceable so tests (and later, downloaded province packs) can swap it.
typedef OfflineMapLoader = Future<VectorTileProvider> Function();

// The Bangkok map pack bundled in the app (Protomaps build 20261113, OpenStreetMap data, ODbL).
// Bump the date in the name whenever the pack is replaced: the phone keeps its own copy by name.
const bangkokPackAsset = 'assets/maps/bangkok-20261113.pmtiles';

// PMTiles is read with random access, which a Flutter asset cannot do, so the pack is copied
// once into the app's own folder and opened from there.
Future<VectorTileProvider> loadBundledBangkokMap() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/${bangkokPackAsset.split('/').last}');
  // The file name carries the build date and a copy is renamed into place only when complete,
  // so an existing file is whole: later launches skip reading 43 MB into memory.
  if (!file.existsSync()) {
    final data = await rootBundle.load(bangkokPackAsset);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await temp.rename(file.path);
  }
  return PmTilesVectorTileProvider.fromSource(file.path);
}

// The map icons (Protomaps' set plus emergency icons drawn for this app), bundled so they work
// offline. Drawn at twice the size so they stay sharp on phone screens.
Future<SpriteStyle> loadMapSprites() async {
  final json = jsonDecode(
    await rootBundle.loadString('assets/maps/sprites/sprites.json'),
  );
  final atlas = await rootBundle.load('assets/maps/sprites/sprites.png');
  return SpriteStyle(
    atlasProvider: () async =>
        atlas.buffer.asUint8List(atlas.offsetInBytes, atlas.lengthInBytes),
    index: SpriteIndexReader().read(json as Map<String, dynamic>),
  );
}
