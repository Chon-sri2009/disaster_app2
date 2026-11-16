import 'dart:ui';

// The only place raw hex colors live; everything else reads them through AppTokens.
abstract final class AppPalette {
  // Neutrals tinted toward cool slate, like enamel signage.
  static const ground = Color(0xFFF3F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0B1B26);
  static const inkMuted = Color(0xFF44566A);
  static const outline = Color(0xFF6B7D8C);
  static const hairline = Color(0xFFD3DCE3);

  // The single accent: deep water blue for navigation and primary actions.
  static const accent = Color(0xFF0B5A7A);
  static const onAccent = Color(0xFFFFFFFF);
  static const accentSoft = Color(0xFFD3E6EF);

  // Alert levels: each pair is at least 4.5:1 for its text.
  static const safe = Color(0xFF14683A);
  static const onSafe = Color(0xFFFFFFFF);
  static const watch = Color(0xFFF2C200);
  static const onWatch = Color(0xFF0B1B26);
  static const warning = Color(0xFFC2410C);
  static const onWarning = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB3121C);
  static const onDanger = Color(0xFFFFFFFF);

  // Calm status tints for banners.
  static const infoBg = Color(0xFFE3EEF4);
  static const offlineBg = Color(0xFFE6EAEE);
  static const errorBg = Color(0xFFF9E3E4);
}
