import 'dart:async';

import 'package:disaster_app2/screens/home_screen.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/place_lookup.dart';
import 'package:disaster_app2/services/sensor_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GPS and the address are held open by the test, so each state can be checked in turn.
class _FakeLocation extends LocationService {
  // ignore: use_super_parameters
  _FakeLocation(StorageService storage)
    : super(storage, lookup: (_, _) async => null);

  final gps = Completer<LocationResult>();
  final place = Completer<Place>();

  @override
  Future<LocationResult> getCurrent() => gps.future;

  @override
  Future<Place> describe(LatLng p) => place.future;
}

void main() {
  late SensorService sensors;
  late _FakeLocation location;

  Future<void> open(WidgetTester tester, {double scale = 1.0}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    sensors = SensorService();
    location = _FakeLocation(storage);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('th'),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: HomeScreen(
            sensors: sensors,
            storage: storage,
            provinces: null,
            location: location,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Removes the tree first so the sensors' timer is cancelled before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    sensors.dispose();
  }

  // Holds the SOS card for the full 1.5 s, then lets go.
  Future<void> holdSos(WidgetTester tester) async {
    final g = await tester.startGesture(tester.getCenter(find.text('SOS')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await g.up();
    await tester.pump();
  }

  final inSheet = find.byType(BottomSheet);
  Finder sheet(Finder f) => find.descendant(of: inSheet, matching: f);
  Finder call1669() => sheet(
    find.ancestor(of: find.textContaining('1669'), matching: find.byType(FilledButton)),
  );

  const waiting = 'กำลังหาตำแหน่งของคุณ…';
  const lost = 'หาตำแหน่งของคุณไม่ได้';
  final somewhere = LatLng(13.75, 100.5);

  testWidgets('sheet opens at once with the call button live while GPS waits', (
    tester,
  ) async {
    await open(tester);
    await holdSos(tester);
    expect(inSheet, findsOneWidget);
    expect(sheet(find.text(waiting)), findsOneWidget);
    final button = tester.widget<FilledButton>(call1669().first);
    expect(button.onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 400));
    expect(call1669().first.hitTestable(), findsOneWidget);
    await finish(tester);
  });

  testWidgets('message appears with the position, then the address fills in', (
    tester,
  ) async {
    await open(tester);
    await holdSos(tester);
    location.gps.complete(LocationResult(point: somewhere));
    await tester.pump();
    await tester.pump();
    expect(sheet(find.text(waiting)), findsNothing);
    final msg = sheet(find.byType(SelectableText));
    expect(msg, findsOneWidget);
    var text = tester.widget<SelectableText>(msg).data!;
    expect(text, contains('https://www.google.com/maps?q='));
    expect(text, contains('ที่อยู่ / Address: -'));

    location.place.complete(const Place(address: 'X'));
    await tester.pump();
    await tester.pump();
    text = tester.widget<SelectableText>(msg).data!;
    expect(text, contains('Address: X'));
    await finish(tester);
  });

  testWidgets('no position at all: error banner, calls still there (1.5x)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await open(tester, scale: 1.5);
    await holdSos(tester);
    location.gps.complete(const LocationResult(issue: LocationIssue.denied));
    await tester.pump();
    await tester.pump();
    expect(sheet(find.text(lost)), findsOneWidget);
    expect(sheet(find.byType(SelectableText)), findsNothing);
    expect(call1669(), findsWidgets);
    expect(sheet(find.textContaining('191')), findsWidgets);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('GPS failed but a saved position exists: banner and message', (
    tester,
  ) async {
    await open(tester);
    await holdSos(tester);
    location.gps.complete(
      LocationResult(
        point: somewhere,
        fromCache: true,
        issue: LocationIssue.timeout,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(sheet(find.textContaining('จึงใช้ตำแหน่งที่บันทึกไว้ล่าสุด')), findsOneWidget);
    final text = tester
        .widget<SelectableText>(sheet(find.byType(SelectableText)))
        .data!;
    expect(text, contains('last saved position'));
    await finish(tester);
  });

  testWidgets('closing the sheet while locating is safe', (tester) async {
    await open(tester);
    await holdSos(tester);
    // Let the sheet finish sliding in so Close is on screen.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(sheet(find.text('ปิด')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(inSheet, findsNothing);
    location.gps.complete(LocationResult(point: somewhere));
    await tester.pump();
    location.place.complete(const Place(address: 'X'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('address lookup that throws leaves Address - and the message', (
    tester,
  ) async {
    await open(tester);
    await holdSos(tester);
    location.gps.complete(LocationResult(point: somewhere));
    await tester.pump();
    location.place.completeError(StateError('boom'));
    await tester.pump();
    await tester.pump();
    final text = tester
        .widget<SelectableText>(sheet(find.byType(SelectableText)))
        .data!;
    expect(text, contains('Address: -'));
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
