import 'package:disaster_app2/data/emergency_numbers.dart';
import 'package:disaster_app2/data/guide_data.dart';
import 'package:disaster_app2/models/guide_topic.dart';
import 'package:disaster_app2/screens/calls_screen.dart';
import 'package:disaster_app2/screens/guide_screen.dart';
import 'package:disaster_app2/services/storage_service.dart';
import 'package:disaster_app2/theme/app_theme.dart';
import 'package:disaster_app2/theme/app_tokens.dart';
import 'package:disaster_app2/widgets/notice_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

// R5 Call and R7 Guide (index and topic pages): ruled lists, no cards. The words and the order
// of the guide are the owner's and must not change.
const _sizes = [Size(360, 640), Size(390, 844)];
const _scales = [1.0, 1.5];

Future<StorageService> _pump(
  WidgetTester tester,
  Widget Function(StorageService) screen, {
  Size size = const Size(390, 844),
  double scale = 1.0,
  bool dark = false,
  bool thai = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: Locale(thai ? 'th' : 'en'),
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: screen(storage)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return storage;
}

// Every ruled row is at least 48 dp tall.
void _expectRowsReachable(WidgetTester tester) {
  final rows = find.byType(RuledRow);
  expect(rows, findsWidgets);
  for (var i = 0; i < rows.evaluate().length; i++) {
    expect(
      tester.getSize(rows.at(i)).height,
      greaterThanOrEqualTo(AppSize.tapTarget),
      reason: 'row $i',
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('Call screen', () {
    Widget screen(StorageService s) => CallsScreen(storage: s);

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final dark in const [false, true]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} x$scale dark=$dark',
            (tester) async {
              await _pump(tester, screen, size: size, scale: scale, dark: dark);
              expect(tester.takeException(), isNull);
              // One ruled row per number, each with a visible Call word and the number.
              expect(find.byType(RuledRow), findsNWidgets(3));
              expect(find.text('โทร'), findsNWidgets(3));
              for (final n in EmergencyNumbers.sos) {
                expect(find.text(n.number), findsOneWidget);
                expect(find.text(n.serviceTh), findsOneWidget);
              }
              _expectRowsReachable(tester);
              // The hint stays, and no card is left.
              expect(
                find.text('แตะเพื่อเปิดหน้าโทรออกพร้อมเบอร์ แล้วกดโทรเอง'),
                findsOneWidget,
              );
              expect(find.byType(Card), findsNothing);
              expect(find.byType(ScreenTitle), findsOneWidget);
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }

    testWidgets('number is 36/700 tabular and a screen reader taps to dial', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await _pump(tester, screen);
      final style = tester.widget<Text>(find.text('1669')).style!;
      expect(style.fontSize, 36);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      final label = find.semantics.byLabel('โทร 1669 การแพทย์ฉุกเฉิน');
      expect(label, findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^โทร 1669'))),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'โทร 1669 การแพทย์ฉุกเฉิน',
        ),
      );
      tester.semantics.tap(label);
      await tester.pump();
      expect(launched, ['tel:1669']);
      handle.dispose();
    });

    testWidgets('English wording', (tester) async {
      await _pump(tester, screen, thai: false);
      expect(find.text('Emergency calls'), findsOneWidget);
      expect(find.text('Call'), findsNWidgets(3));
    });
  });

  group('Guide index', () {
    Widget screen(StorageService s) => GuideScreen(storage: s);
    final firstAid = GuideData.topics
        .where((t) => t.kind == GuideKind.firstAid)
        .toList();
    final disaster = GuideData.topics
        .where((t) => t.kind == GuideKind.disaster)
        .toList();

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final dark in const [false, true]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} x$scale dark=$dark',
            (tester) async {
              await _pump(tester, screen, size: size, scale: scale, dark: dark);
              expect(tester.takeException(), isNull);
              expect(
                find.byType(RuledRow),
                findsNWidgets(GuideData.topics.length),
              );
              _expectRowsReachable(tester);
              expect(find.byType(Card), findsNothing);
              expect(find.byType(ExpansionTile), findsNothing);
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }

    testWidgets('same group titles and topics in the same order', (
      tester,
    ) async {
      // Tall enough that every row is built.
      await _pump(tester, screen, size: const Size(390, 2000));
      expect(find.text('ปฐมพยาบาลด่วน (${firstAid.length})'), findsOneWidget);
      expect(
        find.text('น้ำท่วมและแผ่นดินไหว (${disaster.length})'),
        findsOneWidget,
      );
      final order = [
        for (final t in [...firstAid, ...disaster])
          tester.getTopLeft(find.text(t.titleTh)).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));
    });

    testWidgets(
      'first-aid group has a thick danger rule, the other an ink rule',
      (tester) async {
        await _pump(tester, screen, size: const Size(390, 2000));
        final tk = AppTokens.light;
        final rules = find.byKey(const ValueKey('section-rule'));
        expect(rules, findsNWidgets(2));
        expect(tester.widget<ColoredBox>(rules.at(0)).color, tk.danger);
        expect(tester.widget<ColoredBox>(rules.at(1)).color, tk.ink);
        for (var i = 0; i < 2; i++) {
          expect(tester.getSize(rules.at(i)).height, AppStroke.accent);
        }
      },
    );

    testWidgets('a row opens its topic page, also by screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, screen, size: const Size(390, 2000));
      tester.semantics.tap(find.semantics.byLabel(firstAid.first.titleTh));
      await tester.pumpAndSettle();
      expect(find.byType(GuideTopicScreen), findsOneWidget);
      handle.dispose();
    });
  });

  group('Guide topic page', () {
    for (final topic in GuideData.topics) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          for (final dark in const [false, true]) {
            testWidgets(
              '${topic.title} ${size.width.toInt()}x${size.height.toInt()} '
              'x$scale dark=$dark',
              (tester) async {
                await _pump(
                  tester,
                  (_) => GuideTopicScreen(topic: topic),
                  size: size,
                  scale: scale,
                  dark: dark,
                );
                expect(tester.takeException(), isNull);
                _expectRowsReachable(tester);
                expect(find.byType(Card), findsNothing);
                await tester.pumpWidget(const SizedBox());
              },
            );
          }
        }
      }
    }

    testWidgets('steps are numbered ruled rows in the same words and order', (
      tester,
    ) async {
      final topic = GuideData.topics.first;
      await _pump(
        tester,
        (_) => GuideTopicScreen(topic: topic),
        size: const Size(390, 2400),
      );
      expect(find.byType(RuledRow), findsNWidgets(topic.stepsTh.length));
      var last = -1.0;
      for (final (i, step) in topic.stepsTh.indexed) {
        expect(find.text(step), findsOneWidget);
        final y = tester.getTopLeft(find.text(step)).dy;
        expect(y, greaterThan(last));
        last = y;
        // The number is plain bold text, not a disc.
        final n = tester.widget<Text>(find.text('${i + 1}').first);
        expect(n.style!.fontWeight, FontWeight.w700);
      }
      final discs = find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final d = w.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle;
      });
      expect(discs, findsNothing);
    });

    testWidgets('the longest topic title shows whole at 360x640, 1.5x', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final topic = GuideData.topics.reduce(
        (a, b) => a.titleTh.length >= b.titleTh.length ? a : b,
      );
      await _pump(
        tester,
        (_) => GuideTopicScreen(topic: topic),
        size: const Size(360, 640),
        scale: 1.5,
      );
      final title = find.text(topic.titleTh);
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
      );
      final r = tester.getRect(title);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
      // In the body (not the app bar), kept as a heading for screen readers.
      expect(
        find.descendant(of: find.byType(AppBar), matching: title),
        findsNothing,
      );
      expect(
        tester.getSemantics(title),
        matchesSemantics(label: topic.titleTh, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('first-aid pages end with a full-width 56 dp red call button', (
      tester,
    ) async {
      final topic = GuideData.topics.firstWhere(
        (t) => t.kind == GuideKind.firstAid,
      );
      await _pump(
        tester,
        (_) => GuideTopicScreen(topic: topic),
        size: const Size(390, 2400),
      );
      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(AppSize.primaryButton));
      expect(size.width, 390 - 2 * AppSpace.md);
      expect(find.text('โทร 1669 การแพทย์ฉุกเฉิน'), findsOneWidget);
    });

    testWidgets('disaster pages have no call button', (tester) async {
      final topic = GuideData.topics.firstWhere(
        (t) => t.kind == GuideKind.disaster,
      );
      await _pump(tester, (_) => GuideTopicScreen(topic: topic));
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
