---
name: Disaster Alert & Rescue
description: A posted public notice in your pocket - framed blocks, heavy Thai type, one solid field per alert tier, by day and by night.
colors:
  paper: "#F2EDE2"
  paper-raised: "#FBF8F1"
  ink: "#16140F"
  ink-muted: "#4A463D"
  rule: "#BDB4A1"
  pressed: "#E3DBCA"
  offline-day: "#E6E0D2"
  error-day: "#F6DEDA"
  danger-ink-day: "#A3101A"
  charcoal: "#14130F"
  charcoal-raised: "#1F1D18"
  paper-ink: "#EFE8D8"
  paper-ink-muted: "#B8B09F"
  rule-night: "#6F6858"
  pressed-night: "#2E2B24"
  offline-night: "#26241E"
  error-night: "#3A1A17"
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
  selection: "#F2C20066"
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
  none: "0px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    typography: "{typography.label-large}"
    rounded: "{rounded.none}"
    padding: "0 24px"
    height: "56px"
  button-outlined:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    typography: "{typography.label-large}"
    rounded: "{rounded.none}"
    padding: "0 16px"
    height: "48px"
  button-call-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.label-large}"
    rounded: "{rounded.none}"
    height: "56px"
  notice-frame:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "16px"
  notice-tile:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "16px"
    height: "48px"
  notice-tile-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  notice-tag:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    typography: "{typography.label-medium}"
    padding: "2px 8px"
  sos-block:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.display-large}"
    rounded: "{rounded.none}"
    height: "112px"
  sos-block-compact:
    height: "88px"
  level-field-safe:
    backgroundColor: "{colors.safe}"
    textColor: "{colors.on-safe}"
    typography: "{typography.display-small}"
  level-field-watch:
    backgroundColor: "{colors.watch}"
    textColor: "{colors.on-watch}"
    typography: "{typography.display-small}"
  level-field-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.on-warning}"
    typography: "{typography.display-small}"
  level-field-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-danger}"
    typography: "{typography.display-small}"
  nav-bar:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.label-medium}"
    height: "76px"
  nav-indicator-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  text-field:
    backgroundColor: "{colors.paper-raised}"
    textColor: "{colors.ink}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.none}"
    padding: "16px"
---

# Design System: Disaster Alert & Rescue

Surface: the whole app (Home, Map, Report, Guide, Settings, About, startup notice), Operate mode. Tokens live in `lib/theme/`: raw hex only in `app_palette.dart`, scales in `app_tokens.dart`, Material wiring in `app_theme.dart`. Screens read colors through `context.tokens` and type through `Theme.of(context).textTheme`. Hex values are given once, in the frontmatter above and in the tables below that mirror `AppPalette`.

## Overview

**Creative North Star: "The Posted Public Notice"**

The app is a public notice pinned to a board: square blocks framed in ink, ruled into sections, set in heavy Thai type. The level is a solid field of its tier color with its word and advice on it, and the same 4-step segmented scale is reused for every gauge. It deliberately is not soft rounded cards, pastel banners and a round red hero button.

There are two boards and they follow the phone's setting (`ThemeMode.system`). Day: newsprint paper ground, ink-black 2 dp frames and rules. Night: the same board in charcoal with paper-coloured frames and text. Tier fields and the SOS red are the same on both boards; only the tier colours used as text on the board change. Selection anywhere is an ink block with ground-coloured text.

The scene it is built for: a frightened resident, one hand, often at night or in rain, low brightness, weak or no signal, who must find the level and the SOS in two seconds.

**Key Characteristics:**
- Square corners everywhere; frames and rules instead of shadows.
- One solid field per alert tier, always with icon and word.
- Sarabun 700 for headings, values and labels; 400 for body.
- The segmented level meter is the signature, reused for levels and measured values.
- SOS is a full-width framed red block pinned above the tab bar, press and hold to confirm.
- Day and night boards, both contrast-tested.

## Colors

Ink on paper, no brand accent: ink does the job an accent would (primary buttons, selection, nav indicator). Colour beyond ink and paper means a state.

### Day board

| Token (`AppTokens`) | Palette name | Hex | Use |
|---|---|---|---|
| ground | paper | `#F2EDE2` | screen background, nav bar, app bar |
| surface | paperRaised | `#FBF8F1` | framed blocks, tiles, fields, dialogs, sheets |
| ink | ink | `#16140F` | text, icons, frames, rules, primary button, selected state (15.8:1 on paper) |
| inkMuted | inkMuted | `#4A463D` | captions, unselected nav labels, source lines (8.0:1) |
| hairline | rule | `#BDB4A1` | quiet dividers, offline banner frame, disabled button fill |
| pressed | pressed | `#E3DBCA` | ripple and highlight fill |
| offlineBg | offlineDay | `#E6E0D2` | offline banner, "no live data" level field, empty station cell |
| errorBg | errorDay | `#F6DEDA` | error banner, over-limit reading block |
| dangerInk | dangerInkDay | `#A3101A` | danger as text, icon or frame on the board (6.8:1) |

### Night board

| Token | Palette name | Hex | Use |
|---|---|---|---|
| ground | charcoal | `#14130F` | screen background |
| surface | charcoalRaised | `#1F1D18` | framed blocks, tiles, fields, sheets |
| ink | paperInk | `#EFE8D8` | text, frames, primary button, selected state (15.2:1) |
| inkMuted | paperInkMuted | `#B8B09F` | captions (8.6:1) |
| hairline | ruleNight | `#6F6858` | quiet dividers (3.4:1) |
| pressed | pressedNight | `#2E2B24` | ripple and highlight fill |
| offlineBg | offlineNight | `#26241E` | offline notices |
| errorBg | errorNight | `#3A1A17` | error notices, over-limit block |
| dangerInk | dangerInkNight | `#FF9A90` | danger as text on the board (9.1:1) |

### Alert tiers (same fields on both boards)

| Tier | Icon | Field / text on field | Contrast | Tier as text on day / night board |
|---|---|---|---|---|
| SAFE | check circle | `#1D6B3A` / `#FFFFFF` | 6.5:1 | `#1D6B3A` / `#86D49F` |
| WATCH | eye | `#F2C200` / `#16140F` | 10.9:1 | `#6E5300` / `#F2C200` |
| WARNING | warning triangle | `#B93D0B` / `#FFFFFF` | 5.6:1 | `#A33508` / `#FFA270` |
| DANGER | octagon (`Icons.dangerous`) | `#B3121C` / `#FFFFFF` | 7.0:1 | dangerInk of the board |

`selection` (`#F2C200` at 40% alpha) is the text-selection highlight on both boards.

Every pair above (tier field, tier on ground, tier on surface, ink and inkMuted on every tint, ground on ink, dangerInk on ground, surface and errorBg) is asserted at 4.5:1, and frames at 3:1, for both boards in `test/design_test.dart`.

### Named Rules

**The Ink-Is-The-Accent Rule.** There is no brand colour. Primary actions, selected tabs, selected tiles and tags are ink blocks with ground-coloured text.

**The Colour-Means-State Rule.** Green, yellow, orange and red appear only for an alert tier, SOS, over-limit or the first-aid call button; the one exception is the yellow text-selection highlighter. The base map's own colours are not UI. A new colour needs a state it explains.

**The Calm Offline Rule.** Offline and "no data" use the quiet offlineBg tint with a hairline frame and a cloud or sensor-off icon. Never red.

## Typography

**Font:** Sarabun (SIL OFL), bundled in `assets/fonts/`, weights 400 / 500 / 600 / 700. One family for everything; Thai first, English second.

**Character:** A printed notice: heavy 700 for anything you must read at a glance, plain 400 for reading.

Every style is built by `AppTheme._style` with `leadingDistribution: TextLeadingDistribution.even` and a line height of 1.1 to 1.5, so Thai tone marks and vowels above and below the line are never clipped. Checked at 1.5x text scale in `test/goldens/thai_sample_scale1.5.png` and `home_360x640_scale1.5.png`.

### Hierarchy

| Role | Size / weight / height | Use |
|---|---|---|
| displayLarge | 48 / 700 / 1.1 | "SOS" in the SOS block |
| displaySmall | 36 / 700 / 1.2 | level word, sensor value (tabular figures) |
| headlineMedium | 28 / 700 / 1.25 | screen title in `ScreenHeader`, startup notice title |
| headlineSmall | 24 / 700 / 1.3 | app bar title on pushed pages |
| titleLarge | 22 / 700 / 1.3 | dialog title |
| titleMedium | 18 / 700 / 1.4 | `SectionLabel`, guide step numbers |
| titleSmall | 16 / 700 / 1.4 | row and tile titles, SOS hint |
| bodyLarge | 18 / 400 / 1.5 | level advice (at 500), guide steps, dialog body |
| bodyMedium | 16 / 400 / 1.5 | body, banners, field text |
| bodySmall | 16 / 400 / 1.5, inkMuted | captions, source and "demo data" lines |
| labelLarge | 16 / 700 / 1.4 | buttons |
| labelMedium | 14 / 700 / 1.4 | nav labels, tags, bulletin strip, current meter step |
| labelSmall | 14 / 500 / 1.4, inkMuted | other meter steps, map credit |

displayMedium (40) and headlineSmall exist in the theme for completeness; the build uses the roles listed.

### Named Rules

**The 16 sp Floor Rule.** Body and caption text is 16 sp or more. Only labels (nav, tags, meter steps, map credit) go to 14 sp, and always at 500 or 700.

**The Even Leading Rule.** Never build a `TextStyle` by hand without `leadingDistribution.even`; go through the theme's text styles and `copyWith`.

**The Shrink-Not-Break Rule.** A Thai word in a narrow cell (meter steps) scales down with `FittedBox` rather than breaking mid-syllable.

## Layout

- **Spacing** (`AppSpace`), an 8 dp grid: xs 4 (the one half step, icon-to-text gaps), sm 8, md 16, lg 24, xl 32, xxl 48. Screen gutters are md 16.
- **Shell:** 4 tabs (Home, Map, Report, Guide) in an `IndexedStack` so every tab keeps its state. Settings (language, About) opens from the gear in each `ScreenHeader`. Sensors live on Home.
- **Navigation switch:** bottom `NavigationBar` (76 dp, labels always shown) when width < 600 dp or height < 480 dp; otherwise a labelled `NavigationRail` with a 3 dp ink rule beside it. The bottom bar wears a 3 dp ink rule on top, like the foot of a notice.
- **Home (phone):** `ScreenHeader`, then the level notice, emergency call tiles in a row, nearest shelter, official notices, sensor readings; the SOS block is pinned at the bottom above the tab bar (112 dp on screens 700 dp tall or more, 88 dp below). **Home (wide, >= 600 dp):** the board scrolls on the left; calls and the SOS (30% of height, 112 to 224 dp) sit in a 340 dp side column behind a 3 dp ink rule.
- **Map:** phones get the shelter list as a sheet over the map; wide screens a 340 dp side column.
- **Limits:** content capped at 640 dp wide; the startup notice at 420 dp.
- **Targets:** `AppSize.tapTarget` 48 dp minimum for every control, map markers included; primary buttons and segmented buttons 56 dp.

## Elevation & Depth

Flat. Depth is drawn with lines, not shadows: a 2 dp ink frame lifts a block off the board, a 3 dp rule ends a header or a sheet. Cards, app bar, nav bar and scrolled-under app bars all sit at elevation 0 with no surface tint. Only dialogs, bottom sheets and snackbars use `AppElevation.overlay` (3), and they still carry their frame or top rule.

### Stroke vocabulary (`AppStroke`)
- **rule** (1 dp): dividers, empty meter cells, gauge cells.
- **frame** (2 dp): every notice block, tile, field, outlined button, banner, section label rule, map marker border.
- **heavy** (3 dp): under `ScreenHeader` and app bars, above the tab bar and sheets, around the level notice, the SOS block, the current meter step, a focused field, an over-limit reading.

### Named Rules

**The Frames-Not-Shadows Rule.** A block is separated from the board by its ink frame. Do not add `BoxShadow` or elevation to anything that is not an overlay.

## Shapes

Square. `AppRadius.none` (0) is the only radius in use: buttons, tiles, fields, cards, dialogs, nav indicators, tooltips and snackbars all use a plain `RoundedRectangleBorder` or `BorderRadius.zero`. The two exceptions are functional: sensor markers on the map are ink discs (so they read apart from the square shelter markers), and the "you are here" mark is a dot inside rings.

## Components

### NoticeFrame
The basic block: surface fill (or a given field colour), a 2 dp ink frame painted in front of the content so a filled strip never hides it, md 16 padding. Optional heavier or coloured frame (the over-limit reading uses a 3 dp dangerInk frame on errorBg).

### NoticeTile
A framed block that is a button: ink ripple inside the frame, at least 48 x 48 dp, semantic label. Selected turns it into an ink block with ground-coloured text and icons. Used for call tiles, the nearest shelter, guide tiles and report category choices (two per row, equal height).

### ScreenHeader and SectionLabel
- **ScreenHeader:** tab title in headlineMedium with an optional trailing action (the Settings gear), a 3 dp ink rule beneath. Marked as a header for screen readers.
- **SectionLabel:** titleMedium label with a 2 dp ink rule running the full width behind it; the label sits on a patch of the board colour so a long Thai label is never squeezed. Sheets pass their surface colour.

### NoticeTag
A small ink block with ground-coloured labelMedium text (2 dp x 8 dp padding), for short status marks such as "nearest" or "sample, not a real shelter".

### Level notice (Home)
Three stacked parts inside one 3 dp ink frame: an ink bulletin strip (area and posted time in ground colour), the tier field (48 dp tier icon, "Level n of 4", the level word in displaySmall, advice in bodyLarge 500, all in the tier's on-colour), then a surface strip with the `LevelMeter` and the source line. With no data the field is offlineBg with a sensor-off icon, "No live data" and "Do not assume it is safe". Announced as one live-region label. The field colour change animates over `AppMotion.slow`.

### LevelMeter and SegmentedGauge (signature)
- **LevelMeter:** four equal 20 dp cells, sm 8 apart. Cells up to the current level are filled in their own tier colour; the rest are surface. The current cell has a 3 dp frame and its word in labelMedium; the others a 1 dp frame and labelSmall. Null level leaves every cell empty.
- **SegmentedGauge:** the same cells for a measured value (10 by default): filled in ink up to the value, a heavy ink post at the safe limit, filled cells past the limit in danger red. Fill animates over `AppMotion.base`.

### Reading block (Home)
Title with icon, status word with check or octagon icon, the value in displaySmall with tabular figures, a `SegmentedGauge`, and the safe limit in words. Over the limit: errorBg, 3 dp dangerInk frame, value in dangerInk, live region. Demo readings say "Demo data, not live" with the update time. Live stations show as framed rows with a tier cell on the right (icon + word on the tier field, or an empty offlineBg cell with "–").

### Guide pages
First aid sits on top as large `NoticeTile`s, disaster topics below as rows. A topic page lists numbered steps: the number in a 32 dp ink square (titleMedium, ground colour) beside the step in bodyLarge. First-aid pages end with the red call button.

### SOS block
- **Shape:** full-width square block, danger red, 3 dp ink frame, "SOS" in displayLarge white with the hold hint in titleSmall beside it.
- **Behaviour:** press and hold 1.5 s (`AppMotion.sosHold`); a 10 dp white bar fills across its foot. Medium haptic on press, heavy on completion; an early release empties the bar (instantly with reduce-motion). A short tap does nothing. While finding GPS the bar runs indeterminate and the hint reads "Finding your location…". Screen-reader users confirm with the long-press action.
- **After:** a sheet puts calling first and the ready-made message second.

### Buttons
- **Filled (primary):** ink block, ground text, labelLarge, 56 dp tall, lg 24 side padding, square. Disabled: hairline fill, inkMuted text. The first-aid call button on Guide pages is the one filled button in danger red.
- **Outlined:** 2 dp ink frame, ink text, 48 dp.
- **Text:** ink, underlined at 2 dp thickness, 48 dp target.
- **Segmented:** 56 dp, framed; selected segment is an ink block.

### Inputs / Fields
Filled with surface, square, 2 dp ink border, md 16 padding. Focus: 3 dp ink border. Error: dangerInk border (2 dp, 3 dp focused) and dangerInk message. Label in inkMuted, floating label in labelLarge.

### Status banner (`WarningBanner`)
Framed, icon + message + optional text action. Info: surface with ink frame. Offline: offlineBg with a hairline frame and cloud-off icon. Error: errorBg with a dangerInk frame and icon. Offline and error are live regions.

### Navigation
`NavigationBar` and `NavigationRail` on the ground colour, no elevation. Selected destination: a square ink indicator with a ground-coloured filled icon and a labelMedium 700 label. Unselected: ink outline icon, inkMuted label at 500.

### Map
The offline Protomaps map (OpenStreetMap data, bundled, no internet needed) using Protomaps' light style on both boards. Shelters are 40 dp framed surface squares with an ink icon; sensor stations are 40 dp ink discs; "you are here" is an ink dot in rings. Every marker has a 48 dp tap area and a label. A legend draws the two marker shapes; the credit is labelSmall. If the map pack cannot open, a calm offline banner with "Try again" shows.

### Startup notice
While the map pack is prepared on first launch: a 3 dp-framed notice (max 420 dp) with the app name, a 6 dp ink progress bar and "Preparing the offline map…".

### States

| View | Loading | Empty | Offline / no data | Error |
|---|---|---|---|---|
| Startup | framed startup notice with progress bar | n/a | n/a | app opens anyway; Map shows its own banner |
| Home level | n/a (demo reading is immediate) | n/a | offlineBg field, "No live data", "Do not assume it is safe" | n/a |
| Home readings | n/a | n/a | offline banner: not connected / cannot reach / may be out of date | over-limit block (errorBg, dangerInk frame, octagon) |
| Home SOS | indeterminate bar, "Finding your location…" | n/a | works offline | GPS failure dialog with saved-position fallback |
| Map | startup notice covers first load | "No shelters are saved on this phone yet…" | calm offline banner + "Try again" | same banner |
| Report | "Finding…" on the location button | "No reports yet…" | works offline | GPS and photo errors as banners or snackbar |
| Guide | n/a | n/a | works offline | n/a |
| Settings, About | n/a | n/a | works offline | n/a |

### Motion
`AppMotion` fast 150, base 200, slow 250 ms, and sosHold 1500 ms. Used for the level field colour, gauge fills, the SOS bar release and list expansion. Every duration goes through `context.motion(d)`, which returns zero when the phone's remove-animations setting is on.

## Do's and Don'ts

### Do:
- **Do** give every state icon + text + colour: SAFE check circle, WATCH eye, WARNING triangle, DANGER octagon, offline cloud-off, no data sensor-off.
- **Do** read colours through `context.tokens` and sizes, spacing, strokes and durations from `AppSpace`, `AppStroke`, `AppSize`, `AppIconSize` and `AppMotion`. Add a token before adding a literal.
- **Do** make every control at least 48 dp (`AppSize.tapTarget`) with a screen-reader label; primary actions 56 dp.
- **Do** keep body text at 16 sp or more and build type from the theme so `leadingDistribution.even` is kept.
- **Do** add every new colour pair to the day and night lists in `test/design_test.dart` (4.5:1 text, 3:1 UI).
- **Do** reuse `LevelMeter` / `SegmentedGauge` for any new gauge, and `NoticeFrame` / `NoticeTile` for any new block.
- **Do** pass durations through `context.motion()`.
- **Do** say what is demo, stale or not connected, in the block itself.
- **Do** use the packages already in `pubspec.yaml`; no new packages.

### Don't:
- **Don't** round corners, add shadows or gradients, or use pastel banners: blocks are square and framed.
- **Don't** introduce a brand accent; ink is the accent.
- **Don't** use red, orange, yellow or green in the UI for anything but an alert tier, SOS, over-limit, the first-aid call button or the selection highlighter, and never red for offline.
- **Don't** let a short tap send SOS; it stays press and hold.
- **Don't** reword safety, first-aid or disclaimer text: that wording belongs to the user.
- **Don't** put raw hex outside `lib/theme/app_palette.dart`.

## Open items

- **Fourth tier data:** WARNING exists in the model, tokens and copy; real alert and sensor sources do not feed it yet.
- **Real data:** alert and sensor data are demo or not connected until the backend is live.
- **Night map:** map tiles use the Protomaps light style on both boards; there is no night map style yet.
- **Report:** delete and share for saved reports are not built.
- **Sensor history:** only the latest reading is shown.
