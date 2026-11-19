import 'dart:convert';

import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/services/offline_map.dart';
import 'package:disaster_app2/services/offline_map_theme.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    useScreenshotWriter();
    mockPathProvider();
  });

  testWidgets('an unreadable map file shows the calm banner', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.saveShelters(MockData.shelters);
    await tester.pumpWidget(
      DisasterApp(storage: storage, loadMap: failingLoadMap),
    );
    await tester.pump();
    await tester.tap(find.text('แผนที่').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('เปิดแผนที่ออฟไลน์ไม่ได้'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    await expectLater(
      find.byType(DisasterApp),
      matchesGoldenFile('goldens/map_offline_390x844.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the icon sheet has the emergency icons', (tester) async {
    final json = jsonDecode(
      await tester.runAsync(
        () => rootBundle.loadString('assets/maps/sprites/sprites.json'),
      ) as String,
    ) as Map<String, dynamic>;
    for (final kind in [
      'hospital',
      'pharmacy',
      'police',
      'fire_station',
      'school',
    ]) {
      expect(json, contains(kind));
    }
  });

  test('the style names only files on the phone and the bundled glyph set', () {
    final style = offlineMapStyle(
      packUri: 'file:///data/bangkok.pmtiles',
      spriteUri: 'file:///data/sprites',
      glyphsUri: 'file:///data/glyphs/{fontstack}/{range}.pbf',
      thai: true,
    );
    expect(jsonEncode(style), isNot(contains('http')));
    final layers = style['layers'] as List;
    expect(layers.length, lessThan(60));
    for (final layer in layers.cast<Map<String, Object>>()) {
      final font = (layer['layout'] as Map?)?['text-font'];
      if (font != null) expect(font, ['NotoSans']);
    }
  });

  test('labels use the own name for Thai and the English name for English', () {
    String firstLabelKey(bool thai) {
      final layers = offlineMapLayers(thai: thai);
      final layer = layers.firstWhere((l) => l['id'] == 'pois_emergency');
      final field = (layer['layout'] as Map)['text-field'] as List;
      return jsonEncode(field[1]);
    }

    expect(firstLabelKey(true), '["get","name"]');
    expect(firstLabelKey(false), '["get","name:en"]');
  });
}
