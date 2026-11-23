import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

// Builds the day and night themes: Sarabun type, rounded soft controls, 48 dp targets.
abstract final class AppTheme {
  static const String fontFamily = 'Sarabun';

  // Text style helper: Thai-safe line height with even leading so tone marks are never clipped.
  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double height, {
    bool figures = false,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      // Tabular figures keep big numbers from jittering as they change.
      fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
    );
  }

  static ThemeData light() => _build(AppTokens.light);

  static ThemeData dark() => _build(AppTokens.dark);

  static ThemeData _build(AppTokens t) {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.brand,
      onPrimary: t.onBrand,
      secondary: t.brand,
      onSecondary: t.onBrand,
      error: t.danger,
      onError: t.onDanger,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      outline: t.hairline,
      outlineVariant: t.hairline,
      primaryContainer: t.brandSoft,
      onPrimaryContainer: t.ink,
      secondaryContainer: t.brandSoft,
      onSecondaryContainer: t.ink,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surface,
      surfaceContainerHighest: t.ground,
      surfaceTint: Colors.transparent,
    );

    // Posted notice scale: nothing under 16 sp; weight carries the hierarchy, and 700 is only
    // for display and headlineMedium.
    final text = TextTheme(
      displayLarge: _style(48, FontWeight.w700, t.ink, 1.2, figures: true),
      displayMedium: _style(40, FontWeight.w700, t.ink, 1.25, figures: true),
      displaySmall: _style(36, FontWeight.w700, t.ink, 1.2, figures: true),
      // Not in the brief; defined so no slot falls back to a default under 16 sp.
      headlineLarge: _style(32, FontWeight.w600, t.ink, 1.25),
      headlineMedium: _style(28, FontWeight.w700, t.ink, 1.25),
      headlineSmall: _style(24, FontWeight.w600, t.ink, 1.3),
      titleLarge: _style(22, FontWeight.w600, t.ink, 1.3),
      titleMedium: _style(20, FontWeight.w600, t.ink, 1.4),
      titleSmall: _style(17, FontWeight.w600, t.ink, 1.4),
      bodyLarge: _style(17, FontWeight.w400, t.ink, 1.5),
      bodyMedium: _style(17, FontWeight.w400, t.ink, 1.5),
      bodySmall: _style(16, FontWeight.w400, t.inkMuted, 1.5),
      labelLarge: _style(17, FontWeight.w600, t.ink, 1.4),
      labelMedium: _style(16, FontWeight.w600, t.ink, 1.4),
      labelSmall: _style(16, FontWeight.w400, t.inkMuted, 1.4),
    );

    RoundedRectangleBorder rounded(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    final control = rounded(AppRadius.control);
    const tap = Size(AppSize.tapTarget, AppSize.tapTarget);
    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: t.ground,
      canvasColor: t.ground,
      extensions: [t],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      highlightColor: t.pressed,
      splashColor: t.pressed,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.brand,
        selectionColor: t.selection,
        selectionHandleColor: t.brand,
      ),
      iconTheme: IconThemeData(color: t.ink, size: AppIconSize.md),
      // Pushed pages: a plain ground bar with ink text (the navy band is retired).
      appBarTheme: AppBarTheme(
        backgroundColor: t.ground,
        foregroundColor: t.ink,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.ink),
        actionsIconTheme: IconThemeData(color: t.ink),
        toolbarHeight: AppSize.toolbar,
        systemOverlayStyle: t.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: t.onBrand,
          disabledBackgroundColor: t.hairline,
          disabledForegroundColor: t.inkMuted,
          minimumSize: const Size(AppSize.tapTarget, AppSize.primaryButton),
          shape: control,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tap,
          shape: control,
          foregroundColor: t.brand,
          side: BorderSide(color: t.hairline, width: AppStroke.frame),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: tap,
          shape: control,
          foregroundColor: t.brand,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: tap,
          shape: const CircleBorder(),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: tap,
          shape: control,
          side: BorderSide(color: t.hairline, width: AppStroke.rule),
          backgroundColor: t.surface,
          foregroundColor: t.ink,
          selectedForegroundColor: t.onBrand,
          selectedBackgroundColor: t.brand,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(AppRadius.none),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.ground,
        border: field(t.hairline, AppStroke.rule),
        enabledBorder: field(t.hairline, AppStroke.rule),
        focusedBorder: field(t.brand, AppStroke.frame),
        errorBorder: field(t.dangerInk, AppStroke.frame),
        focusedErrorBorder: field(t.dangerInk, AppStroke.frame),
        labelStyle: text.bodyMedium?.copyWith(color: t.inkMuted),
        floatingLabelStyle: text.labelLarge?.copyWith(color: t.brand),
        errorStyle: text.bodyMedium?.copyWith(color: t.dangerInk),
        contentPadding: const EdgeInsets.all(AppSpace.md),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink,
        textColor: t.ink,
        minVerticalPadding: AppSpace.sm,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: t.brand,
        inactiveTrackColor: t.hairline,
        thumbColor: t.brand,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand,
        linearTrackColor: t.hairline,
        circularTrackColor: t.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.ground),
        actionTextColor: t.ground,
        shape: control,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        elevation: AppElevation.overlay,
        modalElevation: AppElevation.overlay,
        dragHandleColor: t.hairline,
        dragHandleSize: AppSize.dragHandle,
        shape: rounded(AppRadius.none),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: control,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        iconColor: t.inkMuted,
        collapsedIconColor: t.inkMuted,
        textColor: t.ink,
        collapsedTextColor: t.ink,
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: AppStroke.rule,
        space: AppStroke.rule,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: text.labelMedium?.copyWith(color: t.ground),
      ),
    );
  }
}
