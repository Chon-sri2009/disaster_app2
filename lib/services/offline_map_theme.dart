// The stock v4 layer list is only exported from inside the package, so it is imported by path.
// ignore: implementation_imports
import 'package:vector_map_tiles_pmtiles/src/themes/v4/_package.dart' as v4;

// Protomaps' light style (v4, built into the app, needs no internet) as MapLibre layers, tuned to read like a
// consumer map:
// - each label is in the app language: Thai uses the place's own name (Thai in Thailand) with
//   English as the fallback, English uses the English name with the own name as the fallback.
//   The stock rule uses features this renderer may not evaluate;
// - street names start one zoom level earlier and are slightly larger;
// - places get their icon and name: emergency places first, landmarks next, everyday shops and
//   food only when zoomed in close (so panning stays smooth). The zoom limits are set per
//   layer: this renderer reads the data's own min_zoom wrongly, which hid every place.
// Icons come from the bundled sprite sheet; offline_map.dart adds its file path when it writes
// the style, so nothing here names a web address.
List<Map<String, Object>> offlineMapLayers({required bool thai}) {
  final name = thai ? _nameTh : _nameEn;
  return [
    for (final layer in v4.themeLight)
      if (_dropped.contains(layer['id']) ||
          (layer['id'] as String).startsWith('roads_tunnels') ||
          (layer['id'] as String).startsWith('roads_bridges'))
        ...const <Map<String, Object>>[]
      else if (layer['id'] == 'pois') ...[
        _placeLayer('pois_emergency', _emergencyKinds, name, minzoom: 14),
        _placeLayer('pois_key', _keyKinds, name, minzoom: 15),
        _placeLayer('pois_minor', _minorKinds, name, minzoom: 16),
      ] else
        _tuned(layer, name),
  ];
}

// Layers that add little to a rescue map but cost drawing time on every tile (drawing runs on the
// UI thread, so each layer counts toward drag smoothness). Tunnels and bridges are skipped too:
// their roads still show as normal roads.
const _dropped = {
  'landuse_industrial',
  'landuse_military',
  'landuse_wood',
  'landuse_scrub',
  'landuse_glacier',
  'landuse_sand',
  'landuse_aerodrome',
  'landuse_runway',
  'landuse_zoo',
  'landuse_pier',
  'landuse_pedestrian',
  'roads_runway',
  'roads_taxiway',
  'roads_pier',
  'roads_rail',
  'boundaries_country',
  'boundaries',
  'water_waterway_label',
  'water_label_ocean',
  'places_region',
  'places_country',
};

// Places people look for in an emergency: shown from the first zoom level that has labels.
const _emergencyKinds = [
  'hospital',
  'clinic',
  'pharmacy',
  'police',
  'fire_station',
  'shelter',
  'townhall',
];

// Landmarks and public places.
const _keyKinds = [
  'school',
  'university',
  'library',
  'place_of_worship',
  'bus_station',
  'train_station',
  'station',
  'stadium',
  'museum',
  'attraction',
  'park',
  'garden',
  'zoo',
  'beach',
  'forest',
  'marina',
  'peak',
  'aerodrome',
  'ferry_terminal',
];

// Everyday places: shown only when zoomed in close.
const _minorKinds = [
  'supermarket',
  'convenience',
  'restaurant',
  'cafe',
  'fast_food',
  'bar',
  'post_office',
  'theatre',
  'bus_stop',
  'toilets',
];

// The one glyph set bundled for labels (Latin and Thai), so every label uses it.
const _font = ['NotoSans'];

const _nameTh = [
  'coalesce',
  ['get', 'name'],
  ['get', 'name:en'],
];

const _nameEn = [
  'coalesce',
  ['get', 'name:en'],
  ['get', 'name'],
];

// A place layer: the kind's icon with its name beneath, like a consumer map. Written out in
// full because the stock layer draws names in near-white (it only expects parks) and its
// kind test uses a form this renderer does not read: it takes the older
// ["in", "kind", a, b, ...] form, and silently matches nothing for ["in", ["get", ...], ...].
Map<String, Object> _placeLayer(
  String id,
  List<String> kinds,
  List<Object> name, {
  num? minzoom,
}) => {
  'id': id,
  'type': 'symbol',
  'source': 'protomaps',
  'source-layer': 'pois',
  'minzoom': ?minzoom,
  'filter': [
    'all',
    ['has', 'name'],
    ['in', 'kind', ...kinds],
  ],
  'layout': {
    'icon-image': ['get', 'kind'],
    'text-field': name,
    'text-font': _font,
    'text-size': 11,
    'text-max-width': 7,
    'text-anchor': 'top',
  },
  'paint': {
    'text-color': '#5f6368',
    'text-halo-color': '#ffffff',
    'text-halo-width': 1.5,
  },
};

Map<String, Object> _tuned(Map<String, Object> layer, List<Object> name) {
  final layout = layer['layout'];
  if (layout is! Map || !layout.containsKey('text-field')) return layer;
  final isStreet = (layer['id'] as String).startsWith('roads_labels');
  final size = layout['text-size'];
  return {
    ...layer,
    if (layer['id'] == 'roads_other') 'minzoom': 15,
    'layout': {
      ...layout.cast<String, Object>(),
      'text-field': name,
      'text-font': _font,
      if (isStreet && size is num) 'text-size': size + 2,
    },
  };
}
