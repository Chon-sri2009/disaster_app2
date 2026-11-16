import 'package:flutter/material.dart';

import 'app_tokens.dart';

// Builds the one light ThemeData: Sarabun type, flat surfaces, 48 dp controls.
abstract final class AppTheme {
  static const String fontFamily = 'Sarabun';

  // Text style helper: Thai-safe line height with even leading so tone marks are never clipped.
  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double height,
  ) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  // The complete light theme.
  static ThemeData light() {
    const t = AppTokens.light;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.accent,
      onSecondary: t.onAccent,
      error: t.danger,
      onError: t.onDanger,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      outline: t.outline,
      outlineVariant: t.hairline,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.ink,
      surfaceContainerHighest: t.ground,
    );

    final text = TextTheme(
      displayLarge: _style(56, FontWeight.w700, t.ink, 1.1),
      displaySmall: _style(36, FontWeight.w700, t.ink, 1.2),
      headlineMedium: _style(28, FontWeight.w700, t.ink, 1.25),
      headlineSmall: _style(24, FontWeight.w700, t.ink, 1.3),
      titleLarge: _style(22, FontWeight.w600, t.ink, 1.3),
      titleMedium: _style(18, FontWeight.w600, t.ink, 1.4),
      titleSmall: _style(16, FontWeight.w600, t.ink, 1.4),
      bodyLarge: _style(18, FontWeight.w400, t.ink, 1.5),
      bodyMedium: _style(16, FontWeight.w400, t.ink, 1.5),
      bodySmall: _style(16, FontWeight.w400, t.inkMuted, 1.5),
      labelLarge: _style(16, FontWeight.w600, t.ink, 1.4),
      labelMedium: _style(14, FontWeight.w600, t.ink, 1.4),
      labelSmall: _style(14, FontWeight.w500, t.inkMuted, 1.4),
    );

    const tap = Size(AppSize.tapTarget, AppSize.tapTarget);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: t.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: t.ground,
      extensions: const [AppTokens.light],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSize.tapTarget, 56),
          shape: buttonShape,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tap,
          shape: buttonShape,
          foregroundColor: t.accent,
          side: BorderSide(color: t.accent, width: 1.5),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: tap,
          foregroundColor: t.accent,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: t.hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.danger, width: 2),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: t.inkMuted),
        errorStyle: text.bodyMedium?.copyWith(color: t.danger),
        contentPadding: const EdgeInsets.all(AppSpace.md),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        iconColor: t.accent,
        collapsedIconColor: t.inkMuted,
        textColor: t.ink,
        collapsedTextColor: t.ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: AppElevation.none,
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 28,
            color: states.contains(WidgetState.selected)
                ? t.accent
                : t.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accentSoft,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: t.ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: t.inkMuted),
        selectedIconTheme: IconThemeData(size: 28, color: t.accent),
        unselectedIconTheme: IconThemeData(size: 28, color: t.inkMuted),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.hairline,
        thumbColor: t.accent,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      dividerTheme: DividerThemeData(color: t.hairline, thickness: 1, space: 1),
    );
  }
}
