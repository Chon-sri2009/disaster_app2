import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Loads the bundled Sarabun and Material Icons fonts: tests otherwise draw every glyph in the
// wide Ahem test font, which hides real layout and makes screenshots unreadable.
Future<void> loadAppFonts() async {
  final sarabun = FontLoader('Sarabun');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    sarabun.addFont(rootBundle.load('assets/fonts/Sarabun-$w.ttf'));
  }
  await sarabun.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

// Stands in for the 43 MB map pack, which tests must not copy: the map just stays on "loading".
Future<String> neverLoadMap() => Completer<String>().future;

// Stands in for a map file that cannot be opened, so the calm error banner shows.
Future<String> failingLoadMap() =>
    Future.error(const FileSystemException('offline map missing'));

// path_provider asks the platform for a folder; answer with a temp one. for a folder; answer with a temp one.
void mockPathProvider() {
  final cache = Directory.systemTemp.createTempSync('tiles');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => cache.path,
      );
}

// Writes every screenshot to disk and always passes: the screens show a live clock, so a
// pixel comparison would fail on every run. The PNGs are for human review.
class _ScreenshotWriter extends GoldenFileComparator {
  _ScreenshotWriter(this._base);

  final Uri _base;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = File.fromUri(_base.resolveUri(golden));
    await file.create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }
}

// Switches matchesGoldenFile into "save the screenshot" mode for the current test file.
void useScreenshotWriter() {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _ScreenshotWriter(current.basedir);
  }
}
