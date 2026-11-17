import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_map_theme.dart';

// Prepares the offline map and returns the path of its style file, which the map widget opens.
// Replaceable so tests (and later, downloaded province packs) can swap it.
typedef OfflineMapLoader = Future<String> Function();

// The Bangkok map pack bundled in the app (Protomaps build 20261113, OpenStreetMap data, ODbL).
// Bump the date in the name whenever the pack is replaced: the phone keeps its own copy by name.
const bangkokPackAsset = 'assets/maps/bangkok-20261113.pmtiles';

// Label glyphs (Noto Sans, SIL OFL): Latin, Latin extended, Thai and general punctuation.
const _glyphRanges = ['0-255', '256-511', '3584-3839', '8192-8447'];

// The map reads everything from files, which a Flutter asset is not, so the pack, icons and label
// glyphs are copied once into the app's own folder and the style points at them. Nothing here
// touches the network, so the map works with no signal.
Future<String> loadBundledBangkokMap() async {
  final dir = (await getApplicationSupportDirectory()).path;
  final pack = File('$dir/${bangkokPackAsset.split('/').last}');
  // The file name carries the build date and a copy is renamed into place only when complete,
  // so an existing file is whole: later launches skip reading 43 MB into memory.
  if (!pack.existsSync()) {
    final data = await rootBundle.load(bangkokPackAsset);
    final temp = File('${pack.path}.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await temp.rename(pack.path);
  }

  // Icons are drawn at twice the size, so the same sheet serves as both the 1x and 2x set.
  for (final name in ['sprites.json', '@2x.json', 'sprites.png', '@2x.png']) {
    final ext = name.split('.').last;
    final source = 'assets/maps/sprites/sprites.$ext';
    final target = name.startsWith('@') ? 'sprites$name' : name;
    await _copyOnce(source, '$dir/offline-map/$target');
  }
  for (final range in _glyphRanges) {
    await _copyOnce(
      'assets/maps/glyphs/NotoSans/$range.pbf',
      '$dir/offline-map/glyphs/NotoSans/$range.pbf',
    );
  }

  final style = File('$dir/offline-map/style.json');
  await style.writeAsString(
    jsonEncode(
      offlineMapStyle(
        packUri: Uri.file(pack.path).toString(),
        spriteUri: Uri.file('$dir/offline-map/sprites').toString(),
        glyphsUri:
            '${Uri.directory('$dir/offline-map/glyphs')}{fontstack}/{range}.pbf',
      ),
    ),
    flush: true,
  );
  return style.path;
}

Future<void> _copyOnce(String asset, String path) async {
  final file = File(path);
  if (file.existsSync()) return;
  await file.parent.create(recursive: true);
  final data = await rootBundle.load(asset);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}

// The MapLibre style document: the Protomaps layers over the local pack.
Map<String, Object> offlineMapStyle({
  required String packUri,
  required String spriteUri,
  required String glyphsUri,
}) => {
  'version': 8,
  'name': 'offline',
  'glyphs': glyphsUri,
  'sprite': spriteUri,
  'sources': {
    'protomaps': {
      'type': 'vector',
      'url': 'pmtiles://$packUri',
      'attribution': '© OpenStreetMap contributors',
    },
  },
  'layers': offlineMapLayers,
};
