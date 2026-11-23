import 'dart:convert';

import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/sensor_readings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// R-F1: a stale snapshot must never show a station as Safe (hard rule 1). The service already
// turns a stale Safe into "no data"; the station list must do the same. Watch, Warning and
// Danger stay visible when stale (older bad news is never hidden).

const _url = 'https://example.invalid/snapshot';
final _t0 = DateTime.utc(2026, 11, 22, 3);

// generatedAt follows the injected clock at fetch time (every fetch here happens at _t0).
String _snap(String band, {String status = 'ok'}) => jsonEncode({
  'generatedAt': _t0.toIso8601String(),
  'stations': [
    {
      'id': 'a',
      'name': 'Station A',
      'band': band,
      'status': status,
      'waterCm': 100,
      'readingTime': _t0.toIso8601String(),
    },
  ],
});

const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 1.5];

Future<void> _pump(
  WidgetTester tester,
  SensorService sensors,
  Size size,
  double scale,
  bool dark,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.md),
          child: SensorReadings(sensors: sensors),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<SensorService> _make(
  String band,
  DateTime Function() clock, {
  String status = 'ok',
}) async {
  final s = SensorService(
    snapshotUrl: _url,
    fetcher: (_) async => _snap(band, status: status),
    clock: clock,
  );
  await s.refresh();
  return s;
}

void _expectNeutral() {
  expect(find.byIcon(Icons.sensors_off), findsOneWidget);
  expect(find.text('–'), findsOneWidget);
  expect(find.byIcon(Icons.check_circle), findsNothing);
  expect(find.text('Safe'), findsNothing);
  expect(find.text('ปลอดภัย'), findsNothing);
}

void main() {
  for (final size in _sizes) {
    for (final scale in _scales) {
      for (final dark in [false, true]) {
        final tag = '${size.width.toInt()}x${size.height.toInt()} '
            '${scale}x ${dark ? 'dark' : 'light'}';

        testWidgets('stale + safe: neutral dash tag, no Safe ($tag)', (
          tester,
        ) async {
          var now = _t0;
          final s = await _make('safe', () => now);
          now = _t0.add(const Duration(minutes: 6));
          expect(s.isStale, isTrue);
          await _pump(tester, s, size, scale, dark);
          _expectNeutral();
          expect(find.textContaining('May be out of date'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          s.dispose();
        });

        testWidgets('fresh + safe: still the Safe tag ($tag)', (tester) async {
          final s = await _make('safe', () => _t0);
          expect(s.isStale, isFalse);
          await _pump(tester, s, size, scale, dark);
          expect(find.text('Safe'), findsOneWidget);
          expect(find.byIcon(Icons.sensors_off), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          s.dispose();
        });

        testWidgets('stale + danger: still the danger tag ($tag)', (
          tester,
        ) async {
          var now = _t0;
          final s = await _make('danger', () => now);
          now = _t0.add(const Duration(minutes: 6));
          expect(s.isStale, isTrue);
          await _pump(tester, s, size, scale, dark);
          expect(find.text('Danger'), findsOneWidget);
          expect(find.byIcon(Icons.sensors_off), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          s.dispose();
        });
      }
    }
  }

  testWidgets('stale + watch and warning keep their tags', (tester) async {
    for (final (band, word) in [('watch', 'Watch'), ('warning', 'Warning')]) {
      var now = _t0;
      final s = await _make(band, () => now);
      now = _t0.add(const Duration(minutes: 6));
      await _pump(tester, s, const Size(390, 844), 1, false);
      expect(find.text(word), findsOneWidget, reason: band);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    }
  });

  // Time alone makes data stale. The service notifies on its own poll tick when staleness
  // flips (R-F3), so a list drawn as fresh turns neutral once the snapshot ages out.
  testWidgets('a fresh Safe tag turns neutral when the data ages out', (
    tester,
  ) async {
    var now = _t0;
    var offline = false;
    final s = SensorService(
      snapshotUrl: _url,
      fetcher: (_) async =>
          offline ? throw StateError('offline') : _snap('safe'),
      clock: () => now,
    );
    await s.refresh();
    await _pump(tester, s, const Size(390, 844), 1, false);
    expect(find.text('Safe'), findsOneWidget);
    offline = true;
    now = _t0.add(const Duration(minutes: 6));
    await tester.pump(const Duration(seconds: 31));
    _expectNeutral();
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('no usable reading stays neutral (unchanged)', (tester) async {
    final s = await _make('safe', () => _t0, status: 'stale');
    await _pump(tester, s, const Size(390, 844), 1, false);
    _expectNeutral();
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
