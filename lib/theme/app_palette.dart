import 'dart:ui';

// The only place raw hex colors live; everything else reads them through AppTokens.
// "Public notice": newsprint paper and ink by day, the same board in charcoal at night.
abstract final class AppPalette {
  // Day board.
  static const paper = Color(0xFFF2EDE2);
  static const paperRaised = Color(0xFFFBF8F1);
  static const ink = Color(0xFF16140F);
  static const inkMuted = Color(0xFF4A463D);
  static const rule = Color(0xFFBDB4A1);
  static const pressed = Color(0xFFE3DBCA);
  static const offlineDay = Color(0xFFE6E0D2);
  static const errorDay = Color(0xFFF6DEDA);
  static const dangerInkDay = Color(0xFFA3101A);

  // Night board.
  static const charcoal = Color(0xFF14130F);
  static const charcoalRaised = Color(0xFF1F1D18);
  static const paperInk = Color(0xFFEFE8D8);
  static const paperInkMuted = Color(0xFFB8B09F);
  static const ruleNight = Color(0xFF6F6858);
  static const pressedNight = Color(0xFF2E2B24);
  static const offlineNight = Color(0xFF26241E);
  static const errorNight = Color(0xFF3A1A17);
  static const dangerInkNight = Color(0xFFFF9A90);

  // Alert tiers: solid fields, same in both boards. Each pair is at least 4.5:1.
  static const safe = Color(0xFF1D6B3A);
  static const onSafe = Color(0xFFFFFFFF);
  static const watch = Color(0xFFF2C200);
  static const onWatch = Color(0xFF16140F);
  static const warning = Color(0xFFB93D0B);
  static const onWarning = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB3121C);
  static const onDanger = Color(0xFFFFFFFF);

  // Tier colors used as text or icons on the board itself (4.5:1 on paper / charcoal).
  static const safeInkDay = Color(0xFF1D6B3A);
  static const watchInkDay = Color(0xFF6E5300);
  static const warningInkDay = Color(0xFFA33508);
  static const safeInkNight = Color(0xFF86D49F);
  static const watchInkNight = Color(0xFFF2C200);
  static const warningInkNight = Color(0xFFFFA270);

  // Text selection: a highlighter stroke of the watch yellow.
  static const selection = Color(0x66F2C200);
}
