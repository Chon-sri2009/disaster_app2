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

// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

// Elevation: the interface is flat; only dialogs and snackbars lift.
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

// Minimum comfortable tap target (Material says 48 dp).
abstract final class AppSize {
  static const double tapTarget = 48;
  static const double contentMaxWidth = 640;
  static const double wideBreakpoint = 600;
  static const double railMinHeight = 480;
}

// The four alert tiers; the model (AlertLevel) carries all four.
enum AlertTier { safe, watch, warning, danger }

// How one alert tier looks: label, icon (a different shape per tier), and a text-safe color pair.
class LevelStyle {
  const LevelStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;
}

// Theme colors and alert-tier styles, read with context.tokens.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ground,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.outline,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.infoBg,
    required this.offlineBg,
    required this.errorBg,
    required this.danger,
    required this.onDanger,
    required this.levels,
  });

  final Color ground;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color outline;
  final Color hairline;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color infoBg;
  final Color offlineBg;
  final Color errorBg;
  final Color danger;
  final Color onDanger;
  final Map<AlertTier, LevelStyle> levels;

  // The light palette (the only theme).
  static const light = AppTokens(
    ground: AppPalette.ground,
    surface: AppPalette.surface,
    ink: AppPalette.ink,
    inkMuted: AppPalette.inkMuted,
    outline: AppPalette.outline,
    hairline: AppPalette.hairline,
    accent: AppPalette.accent,
    onAccent: AppPalette.onAccent,
    accentSoft: AppPalette.accentSoft,
    infoBg: AppPalette.infoBg,
    offlineBg: AppPalette.offlineBg,
    errorBg: AppPalette.errorBg,
    danger: AppPalette.danger,
    onDanger: AppPalette.onDanger,
    levels: {
      AlertTier.safe: LevelStyle(
        label: 'SAFE',
        icon: Icons.check_circle,
        color: AppPalette.safe,
        onColor: AppPalette.onSafe,
      ),
      AlertTier.watch: LevelStyle(
        label: 'WATCH',
        icon: Icons.visibility,
        color: AppPalette.watch,
        onColor: AppPalette.onWatch,
      ),
      AlertTier.warning: LevelStyle(
        label: 'WARNING',
        icon: Icons.warning,
        color: AppPalette.warning,
        onColor: AppPalette.onWarning,
      ),
      AlertTier.danger: LevelStyle(
        label: 'DANGER',
        icon: Icons.dangerous,
        color: AppPalette.danger,
        onColor: AppPalette.onDanger,
      ),
    },
  );

  // Style for a tier.
  LevelStyle tier(AlertTier tier) => levels[tier]!;

  // Style for the level the sensor service reports today.
  LevelStyle styleFor(AlertLevel level) => switch (level) {
    AlertLevel.safe => tier(AlertTier.safe),
    AlertLevel.watch => tier(AlertTier.watch),
    AlertLevel.warning => tier(AlertTier.warning),
    AlertLevel.danger => tier(AlertTier.danger),
  };

  @override
  AppTokens copyWith() => this;

  // There is only one palette, so blending returns this.
  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) => this;
}

// Shortcuts: context.tokens for colors, context.motion(d) for reduce-motion-aware durations.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;

  // Returns the duration, or zero when the phone's "remove animations" setting is on.
  Duration motion(Duration normal) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : normal;
}
