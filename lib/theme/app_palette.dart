import 'dart:ui';

// The only place raw hex colors live; everything else reads them through AppTokens.
// "Soft cards": a navy header band over a cool grey canvas of white rounded cards by day, and
// the same layout on deep navy at night.
abstract final class AppPalette {
  // Day.
  static const canvas = Color(0xFFF4F6F8);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1B2D);
  static const inkMuted = Color(0xFF515C6B);
  static const hairline = Color(0xFFD3DAE2);
  static const pressed = Color(0xFFE4EAF1);
  static const offlineDay = Color(0xFFE6EBF1);
  static const errorDay = Color(0xFFFBE4E2);
  static const brand = Color(0xFF0B4F8A);
  static const brandSoft = Color(0xFFE1ECF7);
  static const shadow = Color(0x1A0F1B2D);
  static const dangerInkDay = Color(0xFFA3101A);

  // Night.
  static const canvasNight = Color(0xFF0B1220);
  static const cardNight = Color(0xFF152036);
  static const inkNight = Color(0xFFE8EDF4);
  static const inkMutedNight = Color(0xFFA7B2C2);
  static const hairlineNight = Color(0xFF2A3852);
  static const pressedNight = Color(0xFF1F2D47);
  static const offlineNight = Color(0xFF1A2639);
  static const errorNight = Color(0xFF3B1A21);
  static const brandNight = Color(0xFF9CC8F7);
  static const onBrandNight = Color(0xFF0B1220);
  static const brandSoftNight = Color(0xFF1C3556);
  static const headerNight = Color(0xFF0E3560);
  static const dangerInkNight = Color(0xFFFF9A90);

  static const white = Color(0xFFFFFFFF);
  static const onHeaderMuted = Color(0xFFC9DBEE);

  // Alert tiers: solid fields, same in both modes. Each pair is at least 4.5:1.
  static const safe = Color(0xFF1D6B3A);
  static const onSafe = Color(0xFFFFFFFF);
  static const watch = Color(0xFFF2C200);
  static const onWatch = Color(0xFF16140F);
  static const warning = Color(0xFFB93D0B);
  static const onWarning = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB3121C);
  static const onDanger = Color(0xFFFFFFFF);

  // Tier colors used as text or icons on cards and canvas (4.5:1 on both).
  static const safeInkDay = Color(0xFF1D6B3A);
  static const watchInkDay = Color(0xFF6E5300);
  static const warningInkDay = Color(0xFFA33508);
  static const safeInkNight = Color(0xFF86D49F);
  static const watchInkNight = Color(0xFFF2C200);
  static const warningInkNight = Color(0xFFFFA270);

  // Text selection.
  static const selection = Color(0x660B4F8A);
  static const selectionNight = Color(0x669CC8F7);
}
