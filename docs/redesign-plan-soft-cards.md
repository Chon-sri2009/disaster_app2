# Redesign plan: soft cards (adapted from "AI Family Organizer App")

Reference: https://dribbble.com/shots/27892491 (Crevio / Zahid Hasan). This plan borrows the **style**: layout patterns, shape and colour mood. It does not copy any of the shot's content or branding.

## What the reference does

| Pattern | In the shot |
|---|---|
| Header band | A deep navy band holds a small date line, a large greeting, and an avatar on the right. On the second screen the band fades into the page background as a gradient. |
| Canvas | The page is a light cool grey; every block of content sits on it as a white card with about a 16 px radius. There are no visible borders, just a very soft shadow. |
| Card rows | Each card has a title, then rows. A row has a thin coloured accent bar on its left, a bold title, and a muted second line. Rows are separated by hairlines. |
| Status chips | Small rounded pills on the right of a row ("Today", "Tomorrow", "Next Monday"), in navy, teal or grey. |
| Round chips row | A horizontal scroll of round photo chips with labels (School, Library, Hospital, Work, Home). |
| Accordions | Collapsible cards ("To-Dos (1/4)", "Chores (2/3)") with a chevron and checkbox rows. |
| "See all" | A grey pill button centred at the bottom of a card. |
| Bottom nav | A white bar with 5 items. The centre item is a raised navy circle (the AI assistant). |
| Form sheet | A rounded bottom sheet with a round close (X) button floating above it. Labels sit above filled, rounded inputs. |

Palette from the shot: navy `#031231`, deep blue for the header (about `#0B4F8A`), teal `#6E9498`, greys `#DADBDB` and `#5B5D5F`, warm `#B9A99F` and `#90716A`.

## What stays the same (safety rules this redesign does not touch)

- Every alert state shows an icon, text and a colour. The safe, watch, warning and danger tier colours keep their meaning; only their shape changes, to pills and accent bars.
- Tap targets stay at least 48 dp, and body text stays at 16 sp or more.
- Safety and first-aid wording is not changed.
- SOS still needs a press and hold.
- Mock or sample data stays labelled.
- Light and dark modes stay, along with the Phone / Light / Dark choice in Settings.
- Sarabun stays as the font, because it handles Thai well; the shot's sans-serif isn't needed.
- No new packages.

## Changes

### 1. Theme tokens (`app_palette.dart`, `app_tokens.dart`, `app_theme.dart`)

**Light colours**

| Token | Value | Use |
|---|---|---|
| canvas | `#EEF2F6` | page background |
| card | `#FFFFFF` | card surface |
| ink | `#0F1B2D` | text |
| inkMuted | `#5B6472` | secondary text |
| hairline | `#E3E7EC` | row dividers |
| brand | `#0B4F8A` | header band, primary buttons, raised nav button |
| brandSoft | `#E3EEF8` | soft fill behind brand-coloured elements |

**Dark colours**

| Token | Value |
|---|---|
| canvas | `#0B1220` |
| card | `#152036` |
| ink | `#E8EDF4` |
| brand header | `#0A3A66` |

**Shape and depth**

- Radii: cards 16, inputs and tiles 12, pills fully rounded, sheets 24 at the top.
- Elevation: one soft shadow for cards, and none in dark mode (cards are lighter than the canvas instead).

**Removed:** the paper/ink "notice board" tokens and the frame and rule strokes (heavy rules, square shapes). `NoticeFrame` and `ScreenHeader` are replaced.

**Contrast:** every text and chip pair is re-checked against WCAG AA in both modes; the existing contrast test gets the new pairs.

### 2. Shared widgets (they replace those in `widgets/notice.dart`)

| Widget | Does |
|---|---|
| `BrandHeader` | The navy band: date line, title or greeting, and a round settings button on the right. On Home it fades into the canvas. |
| `SoftCard` | A white rounded card with an optional title row: title, a trailing count or chevron. |
| `AccentRow` | A row with a 3 dp coloured left bar, title, subtitle and a trailing chip. It is the building block for shelters, alerts, numbers and guide topics. |
| `StatusPill` | A rounded chip. Variants: tier (safe, watch, warning, danger), neutral and brand. Always has text, and an icon for tiers. |
| `RoundChip` | A round icon with a label underneath, used in horizontal rows. |
| `CollapsibleCard` | The accordion card, used in Guide. |
| `SeeAllButton` | A grey pill. |
| Reworked `LevelMeter` and `SegmentedGauge` | Rounded segments, with the tier pill and icon kept. |
| Reworked `SosHoldButton` | A rounded red card (radius 20) with a soft red glow. The hold progress fills along the bottom as before. |

### 3. Navigation (`main.dart`)

- A white bar with a soft top shadow, and the selected item in brand blue.
- **The centre slot becomes a raised circle for the most urgent action: Call (โทร).** That means reordering the tabs from Home, Call, Map, Report, Guide to **Home, Map, Call (raised), Report, Guide**.
- On wide screens the `NavigationRail` gets the same look, with Call as a filled circle at the top of the rail's items.

### 4. Screens

| Screen | Change |
|---|---|
| **Home** | `BrandHeader` with today's date, a greeting line ("สวัสดี") and the person's area, with the band fading into the canvas. The SOS card overlaps the bottom edge of the band and stays pinned at the top. Below it, in a scroll: **Water level** card (tier pill top-right, rounded meter, source line), a **Quick call** row of `RoundChip`s for the emergency numbers (adapted from the shot's place chips), a **Nearest shelter** card (an `AccentRow` with a distance pill and a sample pill when it's demo data), and an **Official alerts** card (`AccentRow`s with time pills, plus "See all"). |
| **Call** | A `BrandHeader` titled "Emergency call", then one `SoftCard` with an `AccentRow` per number: a round icon, the number large, the service name, and a phone pill. A tap opens the dialer, as now. |
| **Map** | A slim `BrandHeader`; the map gets rounded top corners where it meets the sheet. The sheet has a 24 radius and a handle, with a pill segmented switch (Shelters / Sensors). Shelter rows are `AccentRow`s coloured by status, with a distance pill. Markers become round brand pins with a white ring, with "you are here" as a pulsing blue dot (a static ring when reduce motion is on). |
| **Report** | Laid out like the shot's form: labels above filled rounded inputs. Category becomes a wrap of selectable rounded tiles with icons. The camera, gallery and location choices become three `RoundChip`-style buttons. The address field is the same input style. The submit button is a full-width brand pill. |
| **Guide** | Two `CollapsibleCard`s, "First aid (n)" and "Disasters (n)", using `AccentRow`s with chevrons. The topic page has a `BrandHeader`, numbered steps in brand-soft circles, and the call-1669 button as a red pill. |
| **Settings / About** | A `BrandHeader` with back, then `SoftCard` groups: Language and Theme as pill segmented buttons, and About as an `AccentRow`. |
| **Startup notice and banners** | `WarningBanner` becomes a rounded tinted card with an icon. Offline, error and info keep their colours and icons. |

### 5. Tests and docs

- **Goldens:** all regenerated, phone, tablet, landscape, night and 1.5× text sizes.
- **Widget tests:** updated for the new tab order and for widget types that change: `ScreenHeader` → `BrandHeader`, `NoticeTile` → `AccentRow`.
- **Accessibility test:** tap target, labelled target and text contrast guidelines on every screen, in both modes.
- **Docs:** `DESIGN.md` rewritten for the soft-card system, and `.impeccable/design.json` and the surface brief updated.

## Risks and trade-offs

- **The public-notice look is replaced.** PR #1's visual direction goes away. The structural work stays: 5 tabs, the Call screen, sensors on the map, the theme choice and the address field.
- **Less visual punch at danger levels.** Soft cards read calmer than black-framed notices. To compensate, at warning and danger the water-level card switches to a full tier-coloured fill with white text, and the header band takes the tier colour.
- **Navy header vs. danger red.** The brand blue must never be confused with a tier colour, so it is kept out of tier usage.
- **Shadows on low-end Android.** One small shadow per card is fine; no blur effects.

## Order of work

1. Tokens and theme (light and dark), then the contrast test.
2. Shared widgets.
3. Navigation reorder with the raised Call button.
4. Home, Call, Map, Report, Guide, Settings/About.
5. Goldens, tests, then an `impeccable` finish review.
6. `DESIGN.md` and the impeccable files.
