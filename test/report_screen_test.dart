import 'package:disaster_app2/screens/report_screen.dart';
import 'package:disaster_app2/services/location_service.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The audit (F4): a person must read "not sent" before saving, not only in the toast after.
  Future<void> pump(WidgetTester tester, Locale locale) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: ReportScreen(
              storage: storage,
              location: LocationService(storage, lookup: (_, _) async => null),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the note field is spoken with its label (text-field node)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const Locale('en'));
    final field = find.byType(TextFormField).first;
    await tester.ensureVisible(field);
    await tester.pump();
    final node = tester.getSemantics(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(node.flagsCollection.isTextField, isTrue);
    expect(node.label, contains('Note (optional)'));
    handle.dispose();
  });

  final cases = {
    'th': 'บันทึกในเครื่องนี้เท่านั้น ไม่มีใครได้รับแจ้ง',
    'en': 'Saved on this phone only. No one is told.',
  };
  for (final c in cases.entries) {
    testWidgets('Report says "not sent" above Save before any save (${c.key})', (
      tester,
    ) async {
      await pump(tester, Locale(c.key));
      final save = find.byIcon(Icons.save);
      await tester.ensureVisible(save);
      await tester.pump();
      final line = find.text(c.value);
      expect(line, findsOneWidget);
      // Directly above the Save button, in the same form card.
      expect(
        tester.getBottomLeft(line).dy,
        lessThanOrEqualTo(tester.getTopLeft(save).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
