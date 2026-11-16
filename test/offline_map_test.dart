import 'package:disaster_app2/data/mock_data.dart';
import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/services/offline_map.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:flutter/material.dart';
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
    final sprites = await tester.runAsync(loadMapSprites);
    final names = sprites!.index.spriteByName;
    for (final kind in [
      'hospital',
      'pharmacy',
      'police',
      'fire_station',
      'school',
    ]) {
      expect(names, contains(kind));
    }
  });
}
