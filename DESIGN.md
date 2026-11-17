---
name: Disaster Alert & Rescue
description: Calm, readable soft cards under a navy header band, with the alert level and SOS always first, by day and by night.
colors:
  canvas: "#EEF2F6"
  card: "#FFFFFF"
  ink: "#0F1B2D"
  ink-muted: "#515C6B"
  hairline: "#DCE2E9"
  pressed: "#E4EAF1"
  offline-day: "#E6EBF1"
  error-day: "#FBE4E2"
  brand: "#0B4F8A"
  brand-soft: "#E1ECF7"
  on-header-muted: "#C9DBEE"
  danger-ink-day: "#A3101A"
  canvas-night: "#0B1220"
  card-night: "#152036"
  ink-night: "#E8EDF4"
  ink-muted-night: "#A7B2C2"
  hairline-night: "#2A3852"
  pressed-night: "#1F2D47"
  offline-night: "#1A2639"
  error-night: "#3B1A21"
  brand-night: "#9CC8F7"
  on-brand-night: "#0B1220"
  brand-soft-night: "#1C3556"
  header-night: "#0E3560"
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
    lineHeight: 1.1
  display-small:
    fontFamily: "Sarabun"
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.2
  headline-medium:
    fontFamily: "Sarabun"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.25
  headline-small:
    fontFamily: "Sarabun"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.3
  title-large:
    fontFamily: "Sarabun"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.3
  title-medium:
    fontFamily: "Sarabun"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.4
  title-small:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.4
  body-large:
    fontFamily: "Sarabun"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.5
  body-medium:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  label-large:
    fontFamily: "Sarabun"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.4
  label-medium:
    fontFamily: "Sarabun"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.4
  label-small:
    fontFamily: "Sarabun"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.4
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.card}"
    typography: "{typography.label-large}"
    rounded: "{rounded.pill}"
    padding: "0 24px"
    height: "56px"
  button-outlined:
    backgroundColor: "{colors.card}"
    textColor: "{colors.brand}"
    typography: "{typography.label-large}"
    rounded: "{rounded.pill}"
    height: "48px"
  button-call-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.label-large}"
    rounded: "{rounded.pill}"
    height: "56px"
  header-band:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.card}"
    typography: "{typography.headline-small}"
  soft-card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "16px"
  soft-tile-selected:
    backgroundColor: "{colors.brand-soft}"
    textColor: "{colors.brand}"
    rounded: "{rounded.lg}"
  status-pill:
    backgroundColor: "{colors.brand-soft}"
    textColor: "{colors.brand}"
    typography: "{typography.label-medium}"
    rounded: "{rounded.pill}"
    padding: "4px 12px"
  round-chip:
    backgroundColor: "{colors.brand-soft}"
    textColor: "{colors.brand}"
    size: "56px"
  sos-card:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.display-large}"
    rounded: "{rounded.xl}"
    height: "112px"
  sos-card-compact:
    height: "88px"
  nav-bar:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink-muted}"
    typography: "{typography.label-medium}"
    height: "80px"
  nav-indicator-selected:
    backgroundColor: "{colors.brand-soft}"
    textColor: "{colors.brand}"
  nav-call-circle:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.card}"
    size: "44px"
  text-field:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.md}"
    padding: "16px"
---

# Design System: Disaster Alert & Rescue

Surface: the whole app (Home, Map, Call, Report, Guide, Settings, About, startup notice), Operate mode. Tokens live in `lib/theme/`: raw hex only in `app_palette.dart`, scales in `app_tokens.dart`, Material wiring in `app_theme.dart`. Screens read colours through `context.tokens` and type through `Theme.of(context).textTheme`. Shared widgets are in `lib/widgets/soft_ui.dart`.

## Overview

**Creative North Star: "Soft Cards Under a Navy Band"**

Adapted from the layout language of a family-planner app (Crevio's "AI Family Organizer" shot): a deep navy header band at the top of each tab, a cool grey canvas, white rounded cards with soft shadows, rows marked by a thin coloured accent bar, small rounded pills for status, round shortcut chips, folding cards, and a raised round button in the middle of the tab bar. Only the style is borrowed; content and safety rules are this app's own.

The calm look must never hide danger. At WARNING and DANGER the header band and the water-level card fill with the tier colour, so the whole top of Home changes at a glance.

There are two modes. By default they follow the phone's setting; Settings offers Phone / Light / Dark, saved on the phone (`StorageService.themeMode`). Day: grey canvas, white cards, navy band. Night: deep navy canvas, lighter navy cards with no shadow, a light blue brand. Tier fields and the SOS red are the same in both.

The scene it is built for: a frightened resident, one hand, often at night or in rain, low brightness, weak or no signal, who must find the level and the SOS in two seconds.

**Key Characteristics:**
- Rounded cards (16), tiles and inputs (12), sheets (24), pills fully round.
- A navy header band behind the status bar; pushed pages use the same band as their app bar.
- One brand blue for actions and selection; colour beyond that means a state.
- SOS is a rounded red card pinned over the band's lower edge on Home, press and hold to confirm.
- Every state is icon + text + colour; both modes are contrast-tested.

## Colors

### Day

| Token (`AppTokens`) | Palette name | Hex | Use |
|---|---|---|---|
| ground | canvas | `#EEF2F6` | page background, input fill, flat tiles inside cards |
| surface | card | `#FFFFFF` | cards, tiles, nav bar, sheets, dialogs |
| ink | ink | `#0F1B2D` | text and icons (15.4:1 on canvas) |
| inkMuted | inkMuted | `#515C6B` | captions, unselected nav, source lines (6.0:1 on canvas) |
| hairline | hairline | `#DCE2E9` | dividers, empty meter steps, field borders |
| pressed | pressed | `#E4EAF1` | ripple and highlight |
| offlineBg | offlineDay | `#E6EBF1` | offline banner, "no live data" disc, sample pill |
| errorBg | errorDay | `#FBE4E2` | error banner, over-limit reading |
| dangerInk | dangerInkDay | `#A3101A` | danger as text or outline (7.9:1 on card) |
| brand / onBrand | brand / white | `#0B4F8A` / `#FFFFFF` | primary buttons, selected tab, links, the Call circle (8.4:1) |
| brandSoft | brandSoft | `#E1ECF7` | tint behind brand icons, pills, selected tiles |
| header / onHeader / onHeaderMuted | brand / white / `#C9DBEE` | band and its title and small line |

### Night

| Token | Palette name | Hex |
|---|---|---|
| ground | canvasNight | `#0B1220` |
| surface | cardNight | `#152036` |
| ink | inkNight | `#E8EDF4` |
| inkMuted | inkMutedNight | `#A7B2C2` |
| hairline | hairlineNight | `#2A3852` |
| offlineBg / errorBg | offlineNight / errorNight | `#1A2639` / `#3B1A21` |
| dangerInk | dangerInkNight | `#FF9A90` |
| brand / onBrand | brandNight / onBrandNight | `#9CC8F7` / `#0B1220` |
| brandSoft | brandSoftNight | `#1C3556` |
| header | headerNight | `#0E3560` |

Cards carry `cardShadow` by day (one 12 dp blur at 10% ink) and none at night.

### Alert tiers (same fields in both modes)

| Tier | Icon | Field / text on field | Tier as text, day / night |
|---|---|---|---|
| SAFE | check circle | `#1D6B3A` / `#FFFFFF` | `#1D6B3A` / `#86D49F` |
| WATCH | eye | `#F2C200` / `#16140F` | `#6E5300` / `#F2C200` |
| WARNING | warning triangle | `#B93D0B` / `#FFFFFF` | `#A33508` / `#FFA270` |
| DANGER | octagon (`Icons.dangerous`) | `#B3121C` / `#FFFFFF` | dangerInk |

Every text pair that renders (tier fields, tier text on canvas and card, ink and inkMuted on every tint, brand pairs, header pairs) is asserted at 4.5:1, and brand marks at 3:1, for both modes in `test/design_test.dart`.

### Named Rules

**The One-Blue Rule.** Brand blue is for actions, selection and the header. It is never an alert tier.

**The Colour-Means-State Rule.** Green, yellow, orange and red appear only for an alert tier, SOS, over-limit or the first-aid call. A new colour needs a state it explains.

**The Loud-At-Danger Rule.** At WARNING and DANGER the Home band and water-level card take the tier colour (tested in `design_test.dart`, golden `home_danger_390x844.png`).

**The Calm Offline Rule.** Offline and "no data" use the quiet offlineBg tint with a cloud or sensor-off icon. Never red.

## Typography

**Font:** Sarabun (SIL OFL), bundled, weights 400 / 500 / 600 / 700. Thai first, English second.

Every style is built by `AppTheme._style` with `leadingDistribution: TextLeadingDistribution.even` and line heights from 1.1 to 1.5, so Thai tone marks are never clipped (checked at 1.5x in `thai_sample_scale1.5.png` and `home_360x640_scale1.5.png`).

| Role | Size / weight | Use |
|---|---|---|
| displayLarge | 48 / 700 | "SOS" (held at 1.0x so the hint keeps its room) |
| displaySmall | 36 / 700 | numbers on the Call tab, sensor values |
| headlineMedium | 28 / 700 | the level word on Home |
| headlineSmall | 24 / 700 | header band title |
| titleLarge | 22 / 700 | app bar title on pushed pages, dialog title |
| titleMedium | 18 / 700 | card titles (`SectionLabel`), step numbers |
| titleSmall | 16 / 700 | row titles, SOS hint |
| bodyLarge | 18 / 400 | level advice (500), guide steps |
| bodyMedium / bodySmall | 16 / 400 | body; captions in inkMuted |
| labelLarge | 16 / 700 | buttons |
| labelMedium / labelSmall | 14 / 700, 500 | nav labels, pills, meter steps, band's small line |

**The 16 sp Floor Rule.** Body and caption text is 16 sp or more; only labels go to 14 sp, at 500 or 700.

**The Shrink-Not-Break Rule.** A Thai word in a narrow cell (meter steps, band title) scales down with `FittedBox` rather than breaking mid-syllable.

## Layout

- **Spacing** (`AppSpace`): xs 4, sm 8, md 16, lg 24, xl 32, xxl 48. Screen gutters md 16; cards md 16 apart.
- **Shell:** 5 tabs in an `IndexedStack`: Home, Map, **Call** (centre), Report, Guide. Settings opens from the round gear on each header band.
- **Navigation:** bottom `NavigationBar` (80 dp, white, soft top shadow) when width < 600 dp or height < 480 dp; otherwise a `NavigationRail`. The Call icon is a 44 dp brand circle. In the bottom bar it keeps the 24 dp icon box, so its label lines up, and is drawn lifted. In the rail it sits in place.
- **Header band (`BrandHeader`):** paints behind the status bar (screens use `SafeArea(top: false)`), sets light or dark status-bar icons from the band colour, holds an optional small line above the title and a round action.
- **Home:** the band shows the area line (dropped below 480 dp tall) and the app name. The SOS card overlaps the band's lower edge by 32 dp and stays pinned (112 dp on screens 700 dp tall or more, 88 dp below). Below it, scrolling and lined up with the SOS: water level, quick call, nearest shelter, official notices.
- **Map:** a slim band, the map, and a rounded sheet (24) with a handle and a Shelters | Sensors switch; wide screens get a 340 dp side column.
- **Limits:** content capped at 640 dp; the startup card at 420 dp.
- **Targets:** 48 dp minimum for every control (`AppSize.tapTarget`); primary buttons 56 dp.

## Components (`lib/widgets/soft_ui.dart`)

- **SoftCard:** white rounded card (16) with the soft shadow. An optional outline marks a state (over-limit: 2 dp dangerInk on errorBg) alongside its icon and words.
- **SoftTile:** a SoftCard that is a button. Selected: brandSoft fill with a 2 dp brand outline. `flat` tiles (inside a card) use the canvas fill with no shadow.
- **BrandHeader:** the band (see Layout). Home passes a tier colour at WARNING and DANGER.
- **SectionLabel:** titleMedium card title with an optional trailing pill; `inCard` sits flush with the card's padding.
- **StatusPill:** rounded label with optional icon, brandSoft and brand by default. Tier pills use the tier field and on-colour; "sample" pills use offlineBg and ink.
- **AccentRow:** a 3 dp rounded bar in a state or brand colour, optional leading mark, bold title over a muted line, optional trailing pill or chevron. Tappable rows have a 48 dp minimum.
- **RoundChip:** a 56 dp brandSoft circle with a brand icon and a label underneath. Used for Home's quick-call row.
- **CollapsibleCard:** a SoftCard around an `ExpansionTile`, open by default. Used for the Guide.
- **LevelMeter:** four rounded segments. Steps up to the level are filled in their tier colour, the current one full height and the others half height; empty steps are hairline. Words underneath shrink to fit.
- **SegmentedGauge:** rounded segments in brand up to the value, an ink post at the safe limit, red past it.
- **SosHoldButton:** rounded red card (24) with a surface ring and a red glow. "SOS" sits beside the hint, and a white pill fills along a faint track at its foot while held for 1.5 s. Haptics; a short tap does nothing; screen readers confirm with long-press.
- **WarningBanner:** rounded tinted card with an icon. Info uses brandSoft; offline uses offlineBg; error uses errorBg with a dangerInk outline.

### Screens

- **Water-level card (Home):** the title and a time pill, a 56 dp disc with the tier icon, "Level n of 4" and the level word in tier text colour, the advice, then the meter and source line. At WARNING and DANGER the card fills with the tier colour, and the meter sits in a white well so every step still reads. With no data: offlineBg disc, sensor-off icon, "No live data", "Do not assume it is safe". It is one live-region label.
- **Call:** one SoftTile per number: a brandSoft disc with the service icon, the number in displaySmall, the service name, and a brand "Call" pill. A tap opens the dialer; the person still presses call.
- **Report:** the form in one card. Category and attachment choices are flat tiles with brandSoft icon discs, and a selected tile shows a check on brand. Fields are filled with the canvas colour and rounded (12). The save button is a full-width pill.
- **Guide:** two CollapsibleCards, "Urgent first aid" (red accent bars) and "Floods and earthquakes" (brand bars), with icon discs and chevrons. Topic pages have the steps on one card with numbers in brandSoft circles, and first-aid pages end with the red call pill.
- **Settings:** one card for Language and Theme (pill segmented buttons), one AccentRow card for About.
- **Map markers:** shelters are brand-filled rounded squares with a white ring; stations are white discs with a brand ring; "you are here" is a brand dot in a white ring on a soft halo. 48 dp tap areas and labels.

## Motion

`AppMotion` fast 150, base 200, slow 250 ms, and sosHold 1500 ms. Used for the band and level colour changes, gauge fills, the SOS bar and folding cards. Every duration goes through `context.motion(d)`, which is zero when the phone's remove-animations setting is on.

## Do's and Don'ts

### Do:
- **Do** give every state icon + text + colour.
- **Do** read colours from `context.tokens` and sizes from `AppSpace`, `AppRadius`, `AppStroke`, `AppSize`, `AppIconSize`, `AppMotion`.
- **Do** build new blocks from `soft_ui.dart`; reuse `LevelMeter` / `SegmentedGauge` for gauges.
- **Do** add every new colour pair to both lists in `test/design_test.dart`.
- **Do** say what is demo, stale or not connected, in the card itself.
- **Do** use only the packages already in `pubspec.yaml`.

### Don't:
- **Don't** use brand blue for a level, or a tier colour for decoration.
- **Don't** let a short tap send SOS.
- **Don't** reword safety, first-aid or disclaimer text: that wording belongs to the user.
- **Don't** put raw hex outside `lib/theme/app_palette.dart`.
- **Don't** stack shadows or add blur effects; one soft card shadow by day, none at night.

## Open items

- **Real data:** alert and sensor data are demo or not connected until the backend is live.
- **Fourth tier data:** WARNING exists in the model and tokens; real sources do not feed it yet.
- **Night map style** and saved-report delete/share are not built.
