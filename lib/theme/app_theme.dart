import 'package:flutter/material.dart';

import 'app_tokens.dart';

// Builds the day and night boards: Sarabun type, square ink-framed controls, 48 dp targets.
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

  static ThemeData light() => _build(AppTokens.light);

  static ThemeData dark() => _build(AppTokens.dark);

  static ThemeData _build(AppTokens t) {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.ink,
      onPrimary: t.ground,
      secondary: t.ink,
      onSecondary: t.ground,
      error: t.danger,
      onError: t.onDanger,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      outline: t.ink,
      outlineVariant: t.hairline,
      primaryContainer: t.pressed,
      onPrimaryContainer: t.ink,
      secondaryContainer: t.ink,
      onSecondaryContainer: t.ground,
      surfaceContainerLowest: t.ground,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surface,
      surfaceContainerHighest: t.ground,
      surfaceTint: Colors.transparent,
    );

    // Headings and values in 700 like a printed notice, body in 400.
    final text = TextTheme(
      displayLarge: _style(48, FontWeight.w700, t.ink, 1.1),
      displayMedium: _style(40, FontWeight.w700, t.ink, 1.15),
      displaySmall: _style(36, FontWeight.w700, t.ink, 1.2),
      headlineMedium: _style(28, FontWeight.w700, t.ink, 1.25),
      headlineSmall: _style(24, FontWeight.w700, t.ink, 1.3),
      titleLarge: _style(22, FontWeight.w700, t.ink, 1.3),
      titleMedium: _style(18, FontWeight.w700, t.ink, 1.4),
      titleSmall: _style(16, FontWeight.w700, t.ink, 1.4),
      bodyLarge: _style(18, FontWeight.w400, t.ink, 1.5),
      bodyMedium: _style(16, FontWeight.w400, t.ink, 1.5),
      bodySmall: _style(16, FontWeight.w400, t.inkMuted, 1.5),
      labelLarge: _style(16, FontWeight.w700, t.ink, 1.4),
      labelMedium: _style(14, FontWeight.w700, t.ink, 1.4),
      labelSmall: _style(14, FontWeight.w500, t.inkMuted, 1.4),
    );

    const square = RoundedRectangleBorder();
    final framed = RoundedRectangleBorder(side: t.frame);
    const tap = Size(AppSize.tapTarget, AppSize.tapTarget);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: t.ink, width: AppStroke.frame),
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
        cursorColor: t.ink,
        selectionColor: t.selection,
        selectionHandleColor: t.ink,
      ),
      iconTheme: IconThemeData(color: t.ink, size: AppIconSize.md),
      appBarTheme: AppBarTheme(
        backgroundColor: t.ground,
        foregroundColor: t.ink,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.headlineSmall,
        toolbarHeight: AppSize.toolbar,
        shape: Border(
          bottom: BorderSide(color: t.ink, width: AppStroke.heavy),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.ink,
          foregroundColor: t.ground,
          disabledBackgroundColor: t.hairline,
          disabledForegroundColor: t.inkMuted,
          minimumSize: const Size(AppSize.tapTarget, AppSize.primaryButton),
          shape: square,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tap,
          shape: square,
          foregroundColor: t.ink,
          side: t.frame,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: tap,
          shape: square,
          foregroundColor: t.ink,
          textStyle: text.labelLarge?.copyWith(
            decoration: TextDecoration.underline,
            decorationThickness: 2,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: tap,
          shape: square,
          foregroundColor: t.ink,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(AppSize.tapTarget, AppSize.primaryButton),
          shape: square,
          side: t.frame,
          foregroundColor: t.ink,
          selectedForegroundColor: t.ground,
          selectedBackgroundColor: t.ink,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: framed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: t.ink, width: AppStroke.heavy),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: t.dangerInk, width: AppStroke.frame),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: t.dangerInk, width: AppStroke.heavy),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: t.inkMuted),
        floatingLabelStyle: text.labelLarge,
        errorStyle: text.bodyMedium?.copyWith(color: t.dangerInk),
        contentPadding: const EdgeInsets.all(AppSpace.md),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink,
        textColor: t.ink,
        minVerticalPadding: AppSpace.sm,
        shape: square,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSize.navBar,
        elevation: AppElevation.none,
        backgroundColor: t.ground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.ink,
        indicatorShape: square,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelMedium
              : text.labelMedium?.copyWith(
                  color: t.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppIconSize.md,
            color: states.contains(WidgetState.selected) ? t.ground : t.ink,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.ground,
        indicatorColor: t.ink,
        indicatorShape: square,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: text.labelMedium,
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: t.inkMuted,
          fontWeight: FontWeight.w500,
        ),
        selectedIconTheme: IconThemeData(size: AppIconSize.md, color: t.ground),
        unselectedIconTheme: IconThemeData(size: AppIconSize.md, color: t.ink),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: t.ink,
        inactiveTrackColor: t.hairline,
        thumbColor: t.ink,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.ink,
        linearTrackColor: t.hairline,
        circularTrackColor: t.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.ground),
        actionTextColor: t.ground,
        shape: square,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        elevation: AppElevation.overlay,
        modalElevation: AppElevation.overlay,
        dragHandleColor: t.ink,
        dragHandleSize: AppSize.dragHandle,
        shape: Border(
          top: BorderSide(color: t.ink, width: AppStroke.heavy),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: framed,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        iconColor: t.ink,
        collapsedIconColor: t.ink,
        textColor: t.ink,
        collapsedTextColor: t.ink,
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: AppStroke.rule,
        space: AppStroke.rule,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.ink),
        textStyle: text.labelMedium?.copyWith(color: t.ground),
      ),
    );
  }
}
