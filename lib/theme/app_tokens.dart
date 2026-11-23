import 'package:flutter/material.dart';

import '../models/alert_level.dart';
import 'app_palette.dart';

// 8-dp spacing scale (xs is the one half-step, for icon-to-text gaps).
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// Corner radii: photos and small marks, tiles and inputs, cards, sheets, and fully round pills.
abstract final class AppRadius {
  // Posted notice: square by default, 8 for controls. The rest are LEGACY (remove in R10).
  static const double none = 0;
  static const double control = 8;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

// Line weights: hairline dividers, the selected outline, and the accent bar at a row's start.
abstract final class AppStroke {
  static const double rule = 1;
  static const double frame = 2;
  static const double accent = 3;
  // Posted notice: the selected-tab rule and the tier slab edge.
  static const double tab = 3;
  static const double slab = 8;
}

// Icon sizes.
abstract final class AppIconSize {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}

// Elevation: cards carry a soft token shadow instead; dialogs, sheets and snackbars lift.
abstract final class AppElevation {
  static const double none = 0;
  static const double overlay = 3;
}

// Animation lengths (150 to 250 ms) and the SOS hold time.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);
  static const Duration sosHold = Duration(milliseconds: 1500);
}

// Sizes: tap targets (Material says 48 dp), layout limits and the pinned SOS block.
abstract final class AppSize {
  static const double tapTarget = 48;
  static const double primaryButton = 56;
  static const double contentMaxWidth = 640;
  static const double noticeMaxWidth = 420;
  static const double wideBreakpoint = 600;
  static const double railMinHeight = 480;
  static const double sidePanelWidth = 340;
  static const double sosHeight = 112;
  static const double sosHeightCompact = 88;
  static const double sosHeightTallScreen = 700;
  static const double meterHeight = 20;
  static const double marker = 40;
  static const double toolbar = 64;
  static const double navBar =
      100; // two 16 sp lines at 1.5x need about 98 (tested at 360 wide)
  static const double navRail = 112;
  // The bar is navBar tall up to this text scale, then grows in step with the text.
  static const double navBarFitScale = 1.5;
  // The bar stops growing here (it would otherwise swallow the screen).
  static const double navBarMaxScale = 3;
  // From this text scale up, screens use their short layouts (smaller titles, shorter SOS bar).
  static const double compactTextScale = 1.3;
  // Text size used to read the user's text scale back (scale(probe) / probe).
  static const double textScaleProbe = 16;
  static const double sosBar = 6;
  static const Size dragHandle = Size(40, 4);
  static const double levelCell = 96;
  static const double photoPreview = 160;
  static const double thumb = 56;
  // Posted notice: the vertical staff gauge, one block per tier.
  static const double gaugeWidth = 28;
  // Smallest height of one gauge block; the gauge grows to the slab's height past this.
  static const double gaugeStep = 32;
  // The same on short screens and at large text, where height is scarce.
  static const double gaugeStepCompact = 24;
}

// The four alert tiers; the model (AlertLevel) carries all four.
enum AlertTier { safe, watch, warning, danger }

// How one alert tier looks: label, icon (a different shape per tier), its solid field with the
// text color on it, and the tier color to use for text or icons on the plain board.
class LevelStyle {
  const LevelStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.onGround,
    required this.rule,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;
  final Color onGround;

  // The tier colour as a rule or edge on the board: the field colour by day, the light tier ink
  // at night (the day fields fail 3:1 on the navy ground).
  final Color rule;
}

// Theme colors and alert-tier styles, read with context.tokens.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.mark,
    required this.hairline,
    required this.pressed,
    required this.offlineBg,
    required this.errorBg,
    required this.danger,
    required this.onDanger,
    required this.dangerInk,
    required this.selection,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.header,
    required this.onHeader,
    required this.onHeaderMuted,
    required this.cardShadow,
    required this.levels,
  });

  final Brightness brightness;

  // The page canvas and the cards that sit on it.
  final Color ground;
  final Color surface;

  // Text and icons.
  final Color ink;
  final Color inkMuted;

  // Icon marks and small glyphs: same as inkMuted (3:1 on ground and surface).
  final Color mark;

  // Dividers between list rows and the empty cells of a meter.
  final Color hairline;

  // Pressed and hovered fill.
  final Color pressed;

  // Calm notice tints; text on them is ink.
  final Color offlineBg;
  final Color errorBg;

  // SOS and over-limit field, plus danger as text on the board.
  final Color danger;
  final Color onDanger;
  final Color dangerInk;

  final Color selection;

  // The brand blue: primary buttons, the selected tab, links; onBrand is text on it, brandSoft a
  // quiet tint behind brand-colored icons and numbers.
  final Color brand;
  final Color onBrand;
  final Color brandSoft; // LEGACY: remove in R10 (Posted notice)

  // The header band at the top of each tab, with its text colors. Never used as an alert tier.
  final Color header; // LEGACY: remove in R10 (Posted notice)
  final Color onHeader; // LEGACY: remove in R10 (Posted notice)
  final Color onHeaderMuted; // LEGACY: remove in R10 (Posted notice)

  // The soft shadow under cards (empty at night: cards are lighter than the canvas instead).
  final List<BoxShadow> cardShadow; // LEGACY: remove in R10 (Posted notice)

  final Map<AlertTier, LevelStyle> levels;

  static const _labels = {
    AlertTier.safe: ('SAFE', Icons.check_circle),
    AlertTier.watch: ('WATCH', Icons.visibility),
    AlertTier.warning: ('WARNING', Icons.warning),
    AlertTier.danger: ('DANGER', Icons.dangerous),
  };

  static Map<AlertTier, LevelStyle> _tiers({
    required Color safeInk,
    required Color watchInk,
    required Color warningInk,
    required Color dangerInk,
    required bool night,
  }) => {
    AlertTier.safe: LevelStyle(
      label: _labels[AlertTier.safe]!.$1,
      icon: _labels[AlertTier.safe]!.$2,
      color: AppPalette.safe,
      onColor: AppPalette.onSafe,
      onGround: safeInk,
      rule: night ? safeInk : AppPalette.safe,
    ),
    AlertTier.watch: LevelStyle(
      label: _labels[AlertTier.watch]!.$1,
      icon: _labels[AlertTier.watch]!.$2,
      color: AppPalette.watch,
      onColor: AppPalette.onWatch,
      onGround: watchInk,
      rule: night ? watchInk : AppPalette.watch,
    ),
    AlertTier.warning: LevelStyle(
      label: _labels[AlertTier.warning]!.$1,
      icon: _labels[AlertTier.warning]!.$2,
      color: AppPalette.warning,
      onColor: AppPalette.onWarning,
      onGround: warningInk,
      rule: night ? warningInk : AppPalette.warning,
    ),
    AlertTier.danger: LevelStyle(
      label: _labels[AlertTier.danger]!.$1,
      icon: _labels[AlertTier.danger]!.$2,
      color: AppPalette.danger,
      onColor: AppPalette.onDanger,
      onGround: dangerInk,
      rule: night ? dangerInk : AppPalette.danger,
    ),
  };

  // Day.
  static final light = AppTokens(
    brightness: Brightness.light,
    ground: AppPalette.canvas,
    surface: AppPalette.card,
    ink: AppPalette.ink,
    inkMuted: AppPalette.inkMuted,
    mark: AppPalette.inkMuted,
    hairline: AppPalette.hairline,
    pressed: AppPalette.pressed,
    offlineBg: AppPalette.offlineDay,
    errorBg: AppPalette.errorDay,
    danger: AppPalette.danger,
    onDanger: AppPalette.onDanger,
    dangerInk: AppPalette.dangerInkDay,
    selection: AppPalette.selection,
    brand: AppPalette.brand,
    onBrand: AppPalette.white,
    brandSoft: AppPalette.brandSoft,
    header: AppPalette.brand,
    onHeader: AppPalette.white,
    onHeaderMuted: AppPalette.onHeaderMuted,
    cardShadow: const [
      BoxShadow(color: AppPalette.shadow, blurRadius: 12, offset: Offset(0, 2)),
    ],
    levels: _tiers(
      safeInk: AppPalette.safeInkDay,
      watchInk: AppPalette.watchInkDay,
      warningInk: AppPalette.warningInkDay,
      dangerInk: AppPalette.dangerInkDay,
      night: false,
    ),
  );

  // Night: deep navy canvas, lighter navy cards, a light blue brand.
  static final dark = AppTokens(
    brightness: Brightness.dark,
    ground: AppPalette.canvasNight,
    surface: AppPalette.cardNight,
    ink: AppPalette.inkNight,
    inkMuted: AppPalette.inkMutedNight,
    mark: AppPalette.inkMutedNight,
    hairline: AppPalette.hairlineNight,
    pressed: AppPalette.pressedNight,
    offlineBg: AppPalette.offlineNight,
    errorBg: AppPalette.errorNight,
    danger: AppPalette.danger,
    onDanger: AppPalette.onDanger,
    dangerInk: AppPalette.dangerInkNight,
    selection: AppPalette.selectionNight,
    brand: AppPalette.brandNight,
    onBrand: AppPalette.onBrandNight,
    brandSoft: AppPalette.brandSoftNight,
    header: AppPalette.headerNight,
    onHeader: AppPalette.white,
    onHeaderMuted: AppPalette.onHeaderMuted,
    cardShadow: const [],
    levels: _tiers(
      safeInk: AppPalette.safeInkNight,
      watchInk: AppPalette.watchInkNight,
      warningInk: AppPalette.warningInkNight,
      dangerInk: AppPalette.dangerInkNight,
      night: true,
    ),
  );

  // Style for a tier.
  LevelStyle tier(AlertTier tier) => levels[tier]!;

  // Style for an alert level.
  LevelStyle styleFor(AlertLevel level) => switch (level) {
    AlertLevel.safe => tier(AlertTier.safe),
    AlertLevel.watch => tier(AlertTier.watch),
    AlertLevel.warning => tier(AlertTier.warning),
    AlertLevel.danger => tier(AlertTier.danger),
  };

  @override
  AppTokens copyWith() => this;

  // Light and dark switch whole; there is nothing to blend.
  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 || other is! AppTokens ? this : other;
}

// Shortcuts: context.tokens for colors, context.motion(d) for reduce-motion-aware durations.
extension AppTokensContext on BuildContext {
  // The user's text scale as a plain factor (1.0 = default).
  double get textScale =>
      MediaQuery.textScalerOf(this).scale(AppSize.textScaleProbe) /
      AppSize.textScaleProbe;

  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;

  // Returns the duration, or zero when the phone's "remove animations" setting is on.
  Duration motion(Duration normal) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : normal;
}
