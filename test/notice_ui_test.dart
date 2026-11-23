import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disaster_app2/models/alert_level.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';

import 'test_helpers.dart';

const _thai =
    'ระดับน้ำสูงผิดปกติ โปรดเตรียมพร้อมอพยพขึ้นที่สูงและติดตามประกาศอย่างใกล้ชิด';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double scale = 1.0,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Widget _everything({AlertLevel? level = AlertLevel.warning}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const ScreenTitle(_thai, trailing: Icon(Icons.settings)),
    LevelSlab(
      level: level,
      label: _thai,
      step: _thai,
      advice: _thai,
      sources: const [_thai, _thai],
      posted: _thai,
      area: _thai,
    ),
    SosBar(onConfirmed: () {}, busy: false, height: 112, hint: _thai),
    Section(
      title: _thai,
      children: [
        RuledRow(
          title: _thai,
          subtitle: _thai,
          icon: Icons.phone,
          trailing: const Tag(_thai, icon: Icons.schedule),
          onTap: () {},
        ),
      ],
    ),
  ],
);

AnimatedContainer _slabBox(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(LevelSlab),
        matching: find.byType(AnimatedContainer),
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  group('no overflow', () {
    for (final size in const [Size(360, 640), Size(390, 844)]) {
      for (final scale in const [1.0, 1.5]) {
        for (final dark in const [false, true]) {
          for (final level in <AlertLevel?>[null, ...AlertLevel.values]) {
            testWidgets(
              '${size.width}x${size.height} x$scale dark=$dark $level',
              (tester) async {
                await _pump(
                  tester,
                  _everything(level: level),
                  size: size,
                  scale: scale,
                  dark: dark,
                );
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  });

  group('LevelGauge', () {
    testWidgets('null level fills nothing', (tester) async {
      await _pump(tester, const LevelGauge(level: null));
      expect(find.byKey(const ValueKey('gauge-danger')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.endsWith('-filled'),
        ),
        findsNothing,
      );
    });

    testWidgets('fills only the current tier', (tester) async {
      await _pump(tester, const LevelGauge(level: AlertLevel.watch));
      expect(find.byKey(const ValueKey('gauge-watch-filled')), findsOneWidget);
      expect(find.byKey(const ValueKey('gauge-danger')), findsOneWidget);
      expect(find.byKey(const ValueKey('gauge-safe')), findsOneWidget);
    });
  });

  group('LevelSlab', () {
    Widget slab(AlertLevel? level) => LevelSlab(
      level: level,
      label: 'L',
      advice: 'A',
      sources: const ['S1', 'S2'],
      posted: 'P',
    );

    testWidgets('no data is neutral: sensor-off icon, no fill, no tier colour', (
      tester,
    ) async {
      await _pump(tester, slab(null));
      final t = AppTokens.light;
      expect(find.byIcon(Icons.sensors_off), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.textContaining('-filled'), findsNothing);
      final d = _slabBox(tester).decoration! as BoxDecoration;
      expect(d.color, t.ground);
      expect((d.border! as Border).top.color, t.mark);
      expect((d.border! as Border).top.width, AppStroke.slab);
    });

    testWidgets('safe is quiet with a safe rule', (tester) async {
      await _pump(tester, slab(AlertLevel.safe));
      final t = AppTokens.light;
      final d = _slabBox(tester).decoration! as BoxDecoration;
      expect(d.color, t.ground);
      expect((d.border! as Border).top.color, t.tier(AlertTier.safe).rule);
    });

    testWidgets('watch is quiet with a yellow rule and a yellow icon block', (
      tester,
    ) async {
      await _pump(tester, slab(AlertLevel.watch));
      final t = AppTokens.light;
      final d = _slabBox(tester).decoration! as BoxDecoration;
      expect(d.color, t.ground);
      expect((d.border! as Border).top.color, t.tier(AlertTier.watch).rule);
      final block = tester.widget<Container>(
        find.byKey(const ValueKey('watch-icon-block')),
      );
      expect(block.color, t.tier(AlertTier.watch).color);
    });

    for (final level in [AlertLevel.warning, AlertLevel.danger]) {
      testWidgets('$level fills the slab in the tier colour', (tester) async {
        await _pump(tester, slab(level));
        final t = AppTokens.light;
        final d = _slabBox(tester).decoration! as BoxDecoration;
        expect(d.color, t.styleFor(level).color);
        expect(d.border, isNull);
      });
    }

    testWidgets('one live-region label and each source on its own line', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, slab(AlertLevel.danger));
      expect(find.text('S1'), findsOneWidget);
      expect(find.text('S2'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^L\. ')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the posted time is its own node, not in the live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, slab(AlertLevel.danger));
      final live = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^L\. ')),
      );
      expect(live.label, isNot(contains('P')));
      expect(live.flagsCollection.isLiveRegion, isTrue);
      final posted = tester.getSemantics(find.bySemanticsLabel('P'));
      expect(posted.flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });
  });

  group('SosBar', () {
    testWidgets('a short tap does not confirm', (tester) async {
      var n = 0;
      await _pump(
        tester,
        SosBar(onConfirmed: () => n++, busy: false, height: 112, hint: 'h'),
      );
      await tester.tap(find.byType(SosBar));
      await tester.pump(const Duration(seconds: 2));
      expect(n, 0);
    });

    testWidgets('a 1.5 s hold confirms once', (tester) async {
      var n = 0;
      await _pump(
        tester,
        SosBar(onConfirmed: () => n++, busy: false, height: 112, hint: 'h'),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(SosBar)),
      );
      await tester.pump(); // the first frame only starts the ticker
      await tester.pump(const Duration(milliseconds: 1000));
      expect(n, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(n, 1);
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(n, 1);
    });

    testWidgets('a drag that starts on the bar never confirms', (tester) async {
      var n = 0;
      await _pump(
        tester,
        SosBar(onConfirmed: () => n++, busy: false, height: 112, hint: 'h'),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(SosBar)),
      );
      await tester.pump();
      await g.moveBy(const Offset(0, -(kTouchSlop + 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      expect(n, 0);
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(n, 0);
    });

    testWidgets('a tiny wobble inside the slop still confirms', (tester) async {
      var n = 0;
      await _pump(
        tester,
        SosBar(onConfirmed: () => n++, busy: false, height: 112, hint: 'h'),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(SosBar)),
      );
      await tester.pump();
      await g.moveBy(const Offset(0, kTouchSlop / 4));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(n, 1);
      await g.up();
    });

    testWidgets('a screen reader long-press confirms', (tester) async {
      final handle = tester.ensureSemantics();
      var n = 0;
      await _pump(
        tester,
        SosBar(
          onConfirmed: () => n++,
          busy: false,
          height: 112,
          hint: 'h',
          semanticLabel: 'spoken',
        ),
      );
      tester.semantics.longPress(find.semantics.byLabel('spoken'));
      await tester.pump();
      expect(n, 1);
      handle.dispose();
    });

    testWidgets('busy ignores a hold', (tester) async {
      var n = 0;
      await _pump(
        tester,
        SosBar(onConfirmed: () => n++, busy: true, height: 112, hint: 'h'),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(SosBar)),
      );
      await tester.pump(const Duration(seconds: 2));
      await g.up();
      expect(n, 0);
    });
  });

  group('RuledRow and Tag', () {
    testWidgets('row is at least 48 dp and taps', (tester) async {
      var n = 0;
      await _pump(tester, RuledRow(title: 'x', onTap: () => n++));
      expect(
        tester.getSize(find.byType(RuledRow)).height,
        greaterThanOrEqualTo(AppSize.tapTarget),
      );
      await tester.tap(find.byType(RuledRow));
      expect(n, 1);
    });

    testWidgets('a screen reader can tap a labelled row and an unlabelled one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var labelled = 0;
      var plain = 0;
      await _pump(
        tester,
        Column(
          children: [
            RuledRow(
              title: 'x',
              semanticLabel: 'spoken',
              onTap: () => labelled++,
            ),
            RuledRow(title: 'plain', onTap: () => plain++),
          ],
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('spoken'));
      tester.semantics.tap(find.semantics.byLabel('plain'));
      expect(labelled, 1);
      expect(plain, 1);
      final node = tester.getSemantics(find.bySemanticsLabel('spoken'));
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('trailing sits at the end edge of the row', (tester) async {
      await _pump(
        tester,
        const RuledRow(title: 'x', trailing: Icon(Icons.call, key: Key('t'))),
      );
      final row = tester.getRect(find.byType(RuledRow));
      expect(tester.getRect(find.byKey(const Key('t'))).right, row.right);
    });

    testWidgets('semanticLabel replaces the row text', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        RuledRow(title: 'x', semanticLabel: 'spoken', onTap: () {}),
      );
      expect(find.bySemanticsLabel('spoken'), findsOneWidget);
      handle.dispose();
    });
  });
}
