import 'package:disaster_app2/main.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R3: five equal tabs, the selected one marked by a top rule (no raised Call circle, no pill).
const _labels = ['หน้าแรก', 'แผนที่', 'โทร', 'รายงาน', 'คู่มือ'];

Future<StorageService> _open(
  WidgetTester tester, {
  required Size size,
  double scale = 1.0,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  await tester.pumpWidget(
    DisasterApp(storage: storage, loadMap: failingLoadMap),
  );
  await tester.pump();
  return storage;
}

Color _rule(WidgetTester tester, int i) =>
    tester.widget<ColoredBox>(find.byKey(ValueKey('nav-rule-$i'))).color;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    mockPathProvider();
  });

  testWidgets('five equal tabs with the unchanged labels', (tester) async {
    await _open(tester, size: const Size(390, 844));
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('nav-tab-$i')), findsOneWidget);
    }
    for (final l in _labels) {
      expect(
        find.descendant(of: find.byType(AppNavBar), matching: find.text(l)),
        findsOneWidget,
      );
    }
    // Call has its normal icon, in the ordinary slot: no brand circle behind it.
    expect(
      find.descendant(
        of: find.byType(AppNavBar),
        matching: find.byIcon(Icons.call_outlined),
      ),
      findsOneWidget,
    );
    final sizes = [
      for (var i = 0; i < 5; i++)
        tester.getSize(find.byKey(ValueKey('nav-tab-$i'))),
    ];
    expect(sizes.map((s) => s.width).toSet().length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('selecting a tab moves the top rule and the selected state', (
    tester,
  ) async {
    await _open(tester, size: const Size(390, 844));
    final brand = tester.element(find.byType(AppNavBar)).tokens.brand;
    expect(_rule(tester, 0), brand);
    for (var i = 1; i < 5; i++) {
      expect(_rule(tester, i), Colors.transparent);
    }
    expect(AppStroke.tab, 3);
    expect(tester.getSize(find.byKey(const ValueKey('nav-rule-0'))).height, 3);

    await tester.tap(find.text('โทร'));
    await tester.pump();
    expect(_rule(tester, 2), brand);
    expect(_rule(tester, 0), Colors.transparent);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byKey(const ValueKey('nav-tab-2')),
          matching: find.text('โทร'),
        ),
      ),
      isSemantics(
        label: 'โทร',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tabs are keyboard focusable, Enter activates, outline only on focus', (
    tester,
  ) async {
    await _open(tester, size: const Size(390, 844));
    final focusRings = find.byWidgetPredicate(
      (w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('nav-focus-'),
    );
    expect(focusRings, findsNothing);

    // Tab through the screen until a nav tab takes focus.
    var guard = 0;
    while (focusRings.evaluate().isEmpty && guard++ < 80) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusRings, findsOneWidget);
    // Move to the next tab so we activate something not already selected.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusRings, findsOneWidget);
    final key = tester.widget(focusRings).key! as ValueKey;
    final i = int.parse('${key.value}'.split('-').last);
    expect(i, greaterThan(0));
    final ring = tester.getRect(focusRings);
    final tab = tester.getRect(find.byKey(ValueKey('nav-tab-$i')));
    expect(tab.contains(ring.center), isTrue);
    expect(ring.height, greaterThanOrEqualTo(AppSize.tapTarget));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final brand = tester.element(find.byType(AppNavBar)).tokens.brand;
    expect(_rule(tester, i), brand);
    expect(_rule(tester, 0), Colors.transparent);

    // Space activates too.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final next = i + 1;
    if (next < 5) {
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_rule(tester, next), brand);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one semantics node per tab, with the focus state on it', (
    tester,
  ) async {
    await _open(tester, size: const Size(390, 844));
    final handle = tester.ensureSemantics();
    final label = find.descendant(
      of: find.byKey(const ValueKey('nav-tab-1')),
      matching: find.text('แผนที่'),
    );
    expect(
      tester.getSemantics(label),
      isSemantics(label: 'แผนที่', isButton: true, hasSelectedState: true),
    );
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no raised brand circle in the bar', (tester) async {
    await _open(tester, size: const Size(390, 844));
    final circles = find.descendant(
      of: find.byType(AppNavBar),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(circles, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    for (final scale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        testWidgets('bar fits at ${size.width.toInt()}x${size.height.toInt()} '
            'scale $scale ${dark ? 'dark' : 'light'}', (tester) async {
          await _open(tester, size: size, scale: scale, dark: dark);
          // A RenderFlex overflow would be reported as a test exception.
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 5; i++) {
            final r = tester.getRect(find.byKey(ValueKey('nav-tab-$i')));
            expect(r.height, greaterThanOrEqualTo(AppSize.tapTarget));
            expect(r.width, greaterThanOrEqualTo(AppSize.tapTarget));
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('bar grows with the text so 2.0x at 360 wide clips nothing', (
    tester,
  ) async {
    await _open(tester, size: const Size(360, 640), scale: 2.0);
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(AppNavBar));
    expect(bar.height, greaterThan(AppSize.navBar));
    for (var i = 0; i < 5; i++) {
      final tab = tester.getRect(find.byKey(ValueKey('nav-tab-$i')));
      expect(tab.height, greaterThanOrEqualTo(AppSize.tapTarget));
      expect(tab.width, greaterThanOrEqualTo(AppSize.tapTarget));
      final label = find.descendant(
        of: find.byKey(ValueKey('nav-tab-$i')),
        matching: find.text(_labels[i]),
      );
      final para = tester.renderObject<RenderParagraph>(label);
      expect(para.didExceedMaxLines, isFalse, reason: _labels[i]);
      final text = tester.getRect(label);
      expect(text.top, greaterThanOrEqualTo(tab.top));
      expect(text.bottom, lessThanOrEqualTo(tab.bottom));
      expect(text.left, greaterThanOrEqualTo(tab.left));
      expect(text.right, lessThanOrEqualTo(tab.right));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rail on a wide screen: rule on the leading edge, no overflow', (
    tester,
  ) async {
    await _open(tester, size: const Size(820, 600), scale: 1.5);
    expect(find.byType(AppNavBar), findsNothing);
    expect(find.byType(AppNavRail), findsOneWidget);
    expect(tester.takeException(), isNull);
    final brand = tester.element(find.byType(AppNavRail)).tokens.brand;
    expect(_rule(tester, 0), brand);
    expect(_rule(tester, 1), Colors.transparent);
    // The rule is a vertical bar at the left edge of the selected item.
    final rule = tester.getRect(find.byKey(const ValueKey('nav-rule-0')));
    final tab = tester.getRect(find.byKey(const ValueKey('nav-tab-0')));
    expect(rule.width, 3);
    expect(rule.left, tab.left);
    await tester.tap(find.text('โทร'));
    await tester.pump();
    expect(_rule(tester, 2), brand);
    expect(
      find.descendant(
        of: find.byType(AppNavRail),
        matching: find.byIcon(Icons.call),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
