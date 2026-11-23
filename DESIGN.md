---
name: Disaster Alert & Rescue
description: A posted notice, not a dashboard: flat ground, ruled sections, one level slab with a staff gauge, and a square red SOS bar, readable by day and by night.
colors:
  ground: "#F4F6F8"
  surface: "#FFFFFF"
  ink: "#0F1B2D"
  ink-muted: "#515C6B"
  hairline: "#D3DAE2"
  pressed: "#E4EAF1"
  offline-day: "#E6EBF1"
  error-day: "#FBE4E2"
  brand: "#0B4F8A"
  danger-ink-day: "#A3101A"
  ground-night: "#0B1220"
  surface-night: "#152036"
  ink-night: "#E8EDF4"
  ink-muted-night: "#A7B2C2"
  hairline-night: "#2A3852"
  pressed-night: "#1F2D47"
  offline-night: "#1A2639"
  error-night: "#3B1A21"
  brand-night: "#9CC8F7"
  on-brand-night: "#0B1220"
  danger-ink-night: "#FF9A90"
  safe: "#1D6B3A"
  on-safe: "#FFFFFF"
  watch: "#F2C200"
  on-watch: "#16140F"
  warning: "#B93D0B"
  on-warning: "#FFFFFF"
  danger: "#B3121C"
  on-danger: "#FFFFFF"
  safe-ink-day: "#1D6B3A"
  watch-ink-day: "#6E5300"
  warning-ink-day: "#A33508"
  safe-ink-night: "#86D49F"
  watch-ink-night: "#F2C200"
  warning-ink-night: "#FFA270"
typography:
  display-large:
    fontFamily: "Sarabun"
    fontSize: "48px"
    fontWeight: 700
    lineHeight: 1.2
  display-medium:
    fontFamily: "Sarabun"
    fontSize: "40px"
    fontWeight: 700
    lineHeight: 1.25
  display-small:
    fontFamily: "Sarabun"
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.2
  headline-large:
    fontFamily: "Sarabun"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.25
  headline-medium:
    fontFamily: "Sarabun"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.25
  headline-small:
    fontFamily: "Sarabun"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.3
  title-large:
    fontFamily: "Sarabun"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.3
  title-medium:
    fontFamily: "Sarabun"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.4
  title-small:
    fontFamily: "Sarabun"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.4
  body-large:
    fontFamily: "Sarabun"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.5
  body-medium:
    fontFamily: "Sarabun"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.5
  body-small:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  label-large:
    fontFamily: "Sarabun"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.4
  label-medium:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.4
  label-small:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  none: "0px"
  control: "8px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
components:
  level-slab:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.display-medium}"
    padding: "16px"
  level-slab-loud:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
  sos-bar:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.display-medium}"
    rounded: "{rounded.none}"
    height: "112px"
  sos-bar-compact:
    height: "88px"
  nav-bar:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink-muted}"
    typography: "{typography.label-medium}"
    height: "100px"
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.surface}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    height: "56px"
  button-outlined:
    textColor: "{colors.brand}"
    typography: "{typography.label-large}"
    rounded: "{rounded.control}"
    height: "48px"
  tag:
    textColor: "{colors.ink}"
    typography: "{typography.body-small}"
    rounded: "{rounded.control}"
    padding: "4px 8px"
  text-field:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.ink}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.control}"
    padding: "16px"
---

# Design System: Disaster Alert & Rescue

Surface: the whole app (Home, Map, Call, Report, Guide, Settings, About, alert detail, alert history), Operate mode. Tokens live in `lib/theme/`: raw hex only in `app_palette.dart`, scales and colour roles in `app_tokens.dart`, Material wiring in `app_theme.dart`. Screens read colours through `context.tokens` and type through `Theme.of(context).textTheme`. The Posted notice widgets are in `lib/widgets/notice_ui.dart`; the older `soft_ui.dart` still exists (see Open items).

## Overview

**Creative North Star: "The Posted Notice"**

The app looks like a notice posted on a wall: a flat ground, text on it, thin rules between sections, and one loud block for the level. No cards, no shadows, no header band, no round discs. The level is the biggest thing on Home; at WARNING and DANGER the whole slab fills with the tier colour, so the change is seen at a glance. SOS is a square red bar kept on screen.

There are two modes. By default they follow the phone's setting; Settings offers Phone / Light / Dark, saved on the phone (`StorageService.themeMode`). Day: pale grey ground, white `surface`, ink text. Night: deep navy ground, a light blue brand. Tier fields and the SOS red are the same in both modes; tier text and rules on the ground switch to lighter inks at night.

The scene it is built for: a frightened resident, one hand, often at night or in rain, low brightness, weak or no signal, who must find the level and the SOS in two seconds.

**Key Characteristics:**
- Flat ground. Sections are a title over a 1 dp hairline rule, rows are separated by hairlines. No cards, no elevation on content, no shadows (`AppElevation.overlay` is used only by dialogs, sheets and snackbars through the theme).
- Square by default (`AppRadius.none`); controls (buttons, inputs, tags, choice rows) use `AppRadius.control` 8.
- One slab for the level: an 8 dp tier rule on top for quiet tiers, a full tier-colour fill for WARNING and DANGER, with a vertical staff gauge at its left.
- SOS is a full-width square red bar with a fill bar along its base; hold 1.5 s.
- Five equal tabs, the selected one marked by a 3 dp brand rule across its top, plus ink colour, weight and a filled icon.
- Every state is icon + word + colour, never colour alone. Both modes are contrast-tested.

## Colors

### Day

| Token (`AppTokens`) | Palette name | Hex | Use |
|---|---|---|---|
| ground | canvas | `#F4F6F8` | the page, nav bar, input fill, quiet slab |
| surface | card | `#FFFFFF` | sheets, dialogs, segmented buttons |
| ink | ink | `#0F1B2D` | text and icons |
| inkMuted / mark | inkMuted | `#515C6B` | captions, unselected tabs, source lines, icon marks, empty gauge blocks |
| hairline | hairline | `#D3DAE2` | rules, row separators, input borders |
| pressed | pressed | `#E4EAF1` | ripple and highlight |
| offlineBg | offlineDay | `#E6EBF1` | offline banner tint |
| errorBg | errorDay | `#FBE4E2` | error banner tint |
| dangerInk | dangerInkDay | `#A3101A` | danger as text or outline on the ground |
| brand / onBrand | brand / white | `#0B4F8A` / `#FFFFFF` | primary buttons, selected tab rule, links, selection |

### Night

| Token | Palette name | Hex |
|---|---|---|
| ground | canvasNight | `#0B1220` |
| surface | cardNight | `#152036` |
| ink | inkNight | `#E8EDF4` |
| inkMuted / mark | inkMutedNight | `#A7B2C2` |
| hairline | hairlineNight | `#2A3852` |
| pressed | pressedNight | `#1F2D47` |
| offlineBg / errorBg | offlineNight / errorNight | `#1A2639` / `#3B1A21` |
| dangerInk | dangerInkNight | `#FF9A90` |
| brand / onBrand | brandNight / onBrandNight | `#9CC8F7` / `#0B1220` |

### Alert tiers (fields are the same in both modes)

| Tier | Icon | Field / text on field | Tier as text or rule on the ground, day / night |
|---|---|---|---|
| Safe | check circle | `#1D6B3A` / `#FFFFFF` | `#1D6B3A` / `#86D49F` |
| Watch | eye | `#F2C200` / `#16140F` | `#6E5300` / `#F2C200` |
| Warning | warning triangle | `#B93D0B` / `#FFFFFF` | `#A33508` / `#FFA270` |
| Danger | octagon (`Icons.dangerous`) | `#B3121C` / `#FFFFFF` | `#A3101A` / `#FF9A90` |

`LevelStyle.rule` is the tier colour used as a rule or edge on the ground: the field colour by day, the light tier ink at night (the day fields fail 3:1 on the navy ground). The tier word shown to people always comes from `context.levelLabel` (Thai `ปลอดภัย / เฝ้าระวัง / เตือนภัย / อันตราย`, English `Safe / Watch / Warning / Danger`); the upper-case `LevelStyle.label` strings are not displayed anywhere.

The contrast pairs that render are asserted at 4.5:1 (marks at 3:1) for both modes in `test/design_test.dart`.

### Named Rules

**The One-Blue Rule.** Brand blue is for actions, selection and links. It is never an alert tier.

**The Colour-Means-State Rule.** Green, yellow, orange and red appear only for an alert tier, SOS, over-limit or the first-aid call. A new colour needs a state it explains.

**The Loud-At-Danger Rule.** WARNING and DANGER fill the Home slab and the alert detail tier block with the tier colour. An ended notice (opened from history) never fills: it uses the quiet variant, because it is a record, not a live alert.

**The Calm Offline Rule.** Offline and "no data" are neutral: sensor-off icon, ground colour, a mark-coloured rule. Never green, never red.

## Typography

**Font:** Sarabun (SIL OFL), bundled. Thai first, English second.

Every style is built by `AppTheme._style` with `leadingDistribution: TextLeadingDistribution.even` and line heights 1.2 to 1.5, so Thai tone marks are not clipped. Weight carries the hierarchy; 700 is only for display and headlineMedium.

| Role | Size / weight | Use |
|---|---|---|
| displayLarge | 48 / 700 | large figures |
| displayMedium | 40 / 700 | the level word on the slab, "SOS" |
| displaySmall | 36 / 700 | the tier word on the alert detail block, big numbers |
| headlineLarge | 32 / 600 | defined so no slot falls under 16 sp; not used by the Posted notice screens |
| headlineMedium | 28 / 700 | screen title (`ScreenTitle`) |
| headlineSmall | 24 / 600 | defined, not a main role |
| titleLarge | 22 / 600 | compact screen title, notice headline, dialog title |
| titleMedium | 20 / 600 | section titles (`Section`) |
| titleSmall | 17 / 600 | row titles, SOS hint |
| bodyLarge / bodyMedium | 17 / 400 | advice (500 on the slab), guide steps, body |
| bodySmall | 16 / 400 | captions and source lines in inkMuted, tags (600) |
| labelLarge | 17 / 600 | buttons |
| labelMedium / labelSmall | 16 / 600, 16 / 400 | tab labels, small labels |

**The 16 sp Floor Rule.** Nothing is under 16 sp. Screens must not set a `fontSize` of their own; use the text theme.

**The No-Shrink Rule.** Text wraps; it is never scaled down to fit. The pushed pages put the long title in the body (`ScreenTitle`, compact) instead of the app bar, so long Thai wraps rather than being cut. `FittedBox` survives only in the unused legacy widgets (see Open items).

## Layout

- **Spacing** (`AppSpace`): xs 4, sm 8, md 16, lg 24, xl 32, xxl 48. Screen gutters md 16.
- **Strokes** (`AppStroke`): rule 1, frame 2, accent 3, tab 3, slab 8. **Icons** (`AppIconSize`): sm 20, md 24, lg 32, xl 48.
- **Shell:** five tabs in an `IndexedStack`: Home, Map, Call, Report, Guide, all the same width. Settings opens from a button in each screen title.
- **Navigation:** a bottom bar when width < 600 dp or height < 480 dp, otherwise a side rail (`AppSize.navRail` 112 wide) with the selected rule on its leading edge. The bar is ground colour with a hairline on top. It is `AppSize.navBar` (100 dp) tall up to 1.5x text and grows in step with the text scale above that, up to 3x, so two label lines are not clipped. Each tab has a 48 dp or larger target and one focus stop (Enter and Space activate; a 2 dp ink outline shows on focus).
- **Home:** screen title (area line under it), the level slab edge to edge, then SOS. On screens 700 dp tall or more at under 1.3x text, the slab scrolls away and the SOS bar is pinned under the status bar (112 dp). On shorter screens or at 1.3x text and up, the SOS bar is fixed at the top (88 dp) and the rest scrolls. A short, wide screen puts SOS in its own 340 dp column. Below: water level, quick call, nearest shelter, official notices, other numbers.
- **Map:** the map, and a plain sheet (square top edge under a rule, no shadow) with a grab handle and a two-tab Shelters | Sensors switch with a top rule on the selected tab; wide screens get a 340 dp side column.
- **Pushed pages** (Guide topic, alert detail, alert history, Settings, About): a plain ground app bar. Guide topic, alert detail and About carry the back arrow only and put the title in the body as a compact `ScreenTitle`; alert history and Settings keep a short title in the app bar.
- **Limits:** content is capped at 640 dp (`ContentWidth`); the notice width token is 420.
- **Targets:** 48 dp minimum for every control (`AppSize.tapTarget`); primary buttons 56 dp. **Large text:** `context.textScale` and `AppSize.compactTextScale` (1.3) switch screens to their short layouts.

## Components (`lib/widgets/notice_ui.dart`)

- **ScreenTitle:** the screen title as a semantics header, with an optional trailing control, at least 48 dp tall. `compact` uses titleLarge and no vertical padding.
- **Section:** a title (titleMedium, header semantics) over a hairline rule, then plain children, 32 dp above. An optional thick (3 dp) rule above the title marks a group, with the word still carrying the meaning.
- **RuledRow:** a bare icon or leading widget, title, optional subtitle and trailing mark, a hairline under it, 48 dp minimum. Taps give the whole row; `semanticLabel` replaces the spoken text when words alone are not enough; `selected` marks one choice of a group.
- **Tag:** a small outlined label with an optional icon (control radius, 1 dp edge, 12% tint); fill only when `onColor` is passed. It wraps, never shrinks.
- **LevelGauge:** a vertical staff gauge of four equal blocks with 4 dp gaps, Danger at the top, Safe at the bottom. The current tier is filled, the others outlined (2 dp); no data leaves all blocks empty. It is hidden from screen readers; the word carries the meaning.
- **LevelSlab:** the Home slab, edge to edge. Quiet tiers (safe, watch, no data) sit on the ground under an 8 dp tier rule; watch also puts its icon on a yellow block. WARNING and DANGER fill with the tier colour. It shows the gauge, an icon, the level word (displayMedium), the step line, the advice, source lines and the posted time. The slab is one live region whose spoken text is area, tier word, step, advice and sources; the posted time is its own non-live node, so the screen reader does not re-read it on every refresh.
- **SosBar:** a full-width square red bar: "SOS" and the hint, with a 6 dp progress bar along its base that fills over 1.5 s while held. Haptics on press and on confirm. A short tap does nothing; a touch that moves past the touch slop (a scroll that began on the bar) cancels the hold; screen readers confirm with long-press. It grows taller if the hint needs room at large text.
- **Alert detail tier block:** the tier of one notice on top (icon and word), filled at WARNING and DANGER while the notice is live, quiet with a tier rule when it has ended.
- **Buttons, inputs and bars (themed in `app_theme.dart`):** filled buttons are brand with 56 dp height and 8 dp radius; outlined, text and segmented buttons are 48 dp; inputs are outlined with an 8 dp radius, a ground fill and a 2 dp focus border; the Report form puts each field's label above the field (spoken with the field, tested).
- **WarningBanner (`lib/widgets/warning_banner.dart`):** icon plus message in a tinted block; info, offline (neutral) and error variants.

### Screens

- **Home:** see Layout. With no data the slab is neutral: sensor-off icon, "No live data", "Do not assume it is safe" (the owner's words).
- **Call:** ruled rows, one per number, number large, service name under it, a "Call" mark at the end. A tap opens the dialer; the person still presses call.
- **Report:** the form on the ground. Category choices are bordered 8 dp rows with an icon and word; the chosen row takes a brand outline and a check. A "not sent" line sits above the Save button.
- **Guide:** two sections, urgent first aid (thick red rule) and floods and earthquakes; topics are ruled rows; topic pages are numbered ruled rows, and first-aid pages end with a full-width red call button.
- **Settings and About:** ruled sections; the chosen language and theme are marked with a check.
- **Alert detail and history:** the detail page lists issuer, times, expiry, area and when the app received it; ended notices show an "Ended" banner and never feed any level. History rows carry the tier as an outlined tag.
- **Map markers:** unchanged from the earlier look and not part of the Posted notice pass.

## Motion

`AppMotion` fast 150, base 200, slow 250 ms, and sosHold 1500 ms. Used for the slab colour change and the SOS fill. Every duration goes through `context.motion(d)`, which is zero when the phone's remove-animations setting is on.

## Do's and Don'ts

### Do:
- **Do** give every state icon + word + colour.
- **Do** read colours from `context.tokens` and sizes from `AppSpace`, `AppRadius`, `AppStroke`, `AppSize`, `AppIconSize`, `AppMotion`; read the text scale from `context.textScale`.
- **Do** build new blocks from `notice_ui.dart` (Section, RuledRow, Tag, ScreenTitle).
- **Do** keep text at 16 sp or more, targets at 48 dp or more, and check 1.5x Thai text with no overflow.
- **Do** add every new colour pair to the contrast lists in `test/design_test.dart`.
- **Do** say what is demo, stale or not connected, in the block itself.
- **Do** use only the packages already in `pubspec.yaml`.
- **Do** mark new Thai wording `DRAFT`; the owner approves it.

### Don't:
- **Don't** use brand blue for a level, or a tier colour for decoration.
- **Don't** let a short tap, or a scroll drag, send SOS.
- **Don't** reword safety, first-aid or disclaimer text: that wording belongs to the owner.
- **Don't** put raw hex or a literal font size outside `lib/theme/`.
- **Don't** add cards, shadows, blur or round discs, and don't shrink text with `FittedBox`.

## Open items

Not verified here: whether every screen is free of the legacy items below beyond what a grep of `lib/` shows.

- **Legacy still in use:** `SoftCard` in the startup notice (`lib/main.dart`) and in the Home SOS sheet; `SectionLabel` in the Home SOS sheet and nearby sections (`lib/screens/home_screen.dart`); `SegmentedGauge` in the demo sensor readings (`lib/widgets/sensor_readings.dart`). These are the only uses of `soft_ui.dart` and `level_meter.dart` that grep finds in `lib/`.
- **Legacy unused (grep finds no use in `lib/`):** `StatusPill`, `BrandHeader`, `AccentRow`, `SoftTile`, `RoundChip`, `CollapsibleCard` in `soft_ui.dart`; `LevelMeter` in `level_meter.dart`; `lib/widgets/sos_hold_button.dart` (replaced by `SosBar`). Remove with `soft_ui.dart` in R10.
- **Legacy tokens kept for those widgets:** `header`, `onHeader`, `onHeaderMuted`, `cardShadow`, `brandSoft` (and the palette values behind them), and `AppRadius` `sm`, `md`, `lg`, `xl`, `pill`. Also `surface` is now rarely used. Remove in R10.
- **Literals left in the theme:** the slider track (8 dp) and overlay / thumb radii (24, 14) in `app_theme.dart`.
- **Stale-Safe tag on sensor readings** (`lib/widgets/sensor_readings.dart`): logged as R-F1 for the owner; not changed in this pass.
- **Wording:** new strings in the Posted notice pass are DRAFT until the owner approves the Thai; see the roadmap.
- **Real data:** alert and sensor data are demo or not connected until the backend is live.
- **Night map style** and saved-report delete/share are not built.
