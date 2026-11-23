# Redesign audit: everything that can be redesigned

Date: 2026-11-17. Method: source read of `lib/` plus the rendered goldens in `test/goldens/`, checked against the ui-ux-pro-max rules (accessibility, touch, layout, type/color, motion, navigation) and the Flutter stack guidance. No device or emulator was run. The goldens may lag the code slightly.

This is a redesign inventory, not a rerun of the accessibility audit (`audit-after.md`, 15/20). The current UI is safe and correct. It is plain: it reads like a well-built prototype, not a finished product.

Tags: **UI** = pure visual or layout work, no product decision needed. **DECIDE** = needs a product, data-model or copy decision from you first.

---

## 0. Before redesigning: the baseline docs are out of date

| # | Issue | Where | Tag |
|---|---|---|---|
| 0.1 | `DESIGN.md` says "All strings are English" and audit F17 says "No Thai copy". The app is now fully bilingual through `context.tr(th:, en:)`, and the goldens render in Thai. | `DESIGN.md` "Not built, on purpose"; `docs/audit-after.md` F17 | UI |
| 0.2 | `DESIGN.md` doesn't describe the live-stations view, official alerts on Home, the About screen, the map-loading gate or the SOS bottom sheet. | `DESIGN.md` Components / States | UI |

Update `DESIGN.md` first, so the redesign starts from what exists.

## 1. Design-system level (affects every screen)

| # | What to redesign | Now | Direction | Tag |
|---|---|---|---|---|
| 1.1 | **Night theme** | Light theme only (`main.dart` sets `theme:` only, no `darkTheme:`). Yet `PRODUCT.md`'s own usage scene is "at night, in rain, on low brightness". | Add a dark `AppTokens` set and contrast-test it in `design_test.dart`. This is the biggest open direction question. | DECIDE |
| 1.2 | **Visual direction** | "Flood gauge board": flat, hairline cards, one accent. Coherent and tested, but generic Material on most screens. | Keep it and push it further (signage-style section headers, gauge motifs, bolder tier fields), or choose a new direction. | DECIDE |
| 1.3 | **Icon system** | Filled and outlined Material icons are mixed at the same level (nav uses outlined/filled pairs; cards use filled `Icons.water`, `Icons.report` and `Icons.home_work`). Sizes are 22/24/28/40/56 with no tokens. | Pick one family and style per level. Add `AppIconSize` tokens (sm 20, md 24, lg 32, xl 56). | UI |
| 1.4 | **Elevation and depth** | Everything is flat, with a 1 px hairline. Cards, banners and the background differ only slightly (`#F3F6F8` vs `#FFF`). | Define 2–3 surface levels (ground, raised card, emphasized card) so hierarchy reads at a glance on a dim screen. | UI |
| 1.5 | **Section headers** | Plain `headlineMedium` text at the top of each tab. No app bar, and no consistent title zone. | Make one shared screen-header component: title, optional subtitle or status, optional action. Use it on all tabs. | UI |
| 1.6 | **Motion** | Only the gauge, SOS ring and guide accordion animate. Page, sheet and tab changes use Flutter defaults. Tab switches are instant through `IndexedStack`. | Use one motion spec: a fade-through on tab switch, slide-up sheets, and a tier-change pulse on the level band. Respect `context.motion()`. | UI |
| 1.7 | **Status component family** | `WarningBanner` has 3 kinds (info, offline, error) that all look alike: tinted box and icon. It is used for empty states, errors, alerts and disclaimers. | Split into distinct components: an inline notice, an empty-state block (illustration or icon, title, body, action), an alert card (tier color, sender, time), and an error with retry. | UI |
| 1.8 | **Startup / loading** | Bare `CircularProgressIndicator` and one line of text (`main.dart:89`). | Branded splash: app mark, name, and progress that says what is being prepared. | UI |
| 1.9 | **App identity** | No logo or wordmark anywhere in the UI. | An app mark for the splash, About and the launcher icon. | DECIDE (name/brand) |
| 1.10 | **Typography rhythm** | The scale is good (Sarabun, Thai-safe line heights). But body, bodySmall and labelLarge are all 16 sp, so captions and body barely differ except in color. | Keep the sizes for accessibility. Separate the roles more by weight and color, and use a numeric display style for values. | UI |

## 2. Navigation and information architecture

| # | What | Now | Direction | Tag |
|---|---|---|---|---|
| 2.1 | **Language switch is buried** | Global setting, but it lives only in the Guide tab header (`guide_screen.dart:36`). | Move it to a settings or menu entry reachable from every tab, or to the Home header. | DECIDE |
| 2.2 | **About / disclaimer** | A list row at the bottom of the Guide (`guide_screen.dart:85`). | Settings/menu: language, About, data sources, saved position, and later notifications. | DECIDE |
| 2.3 | **Five tabs** | Home, Sensors, Map, Report, Guide. Sensors and Home overlap (water level shows on both). | Consider merging Sensors into Home as a "details" drill-down, freeing a tab for Settings or keeping 4. | DECIDE |
| 2.4 | **Nav bar styling** | Stock M3 `NavigationBar`, 80 dp high, with a pale indicator. | Restyle: a stronger selected state, a possible SOS shortcut, and a badge when the level is above Safe. | UI |
| 2.5 | **Tablet rail** | Five items stacked at the top. The rest of the rail is empty (`home_tablet-820x1180.png`). | Center the group or add a header/footer (app mark, language). | UI |

## 3. Home (`lib/screens/home_screen.dart`)

The most important screen. Most of the redesign value is here.

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 3.1 | **Level band hierarchy inverted** | The source line ("demo data, not real") sits *above* the level word (`home_screen.dart:249-266`), so the first thing read is a caveat. | Order it as: level word (largest), then advice, then the source/time in a small chip. | UI |
| 3.2 | **Level band feels thin** | 56 dp icon and 36 sp word on a short strip. | Make it a taller hero field with a bigger icon, the area name, and an "updated hh:mm" chip. On Danger: a stronger treatment and optional slow pulse. | UI |
| 3.3 | **Dead space** | At 390x844 there is a large empty gap between the water meter and the SOS panel (`home_phone-390x844.png`). | Use it for a quick-actions row or a nearest-shelter card, or shrink the gap. | UI |
| 3.4 | **No quick-dial on Home** | Emergency numbers (1669, 191, 199, 1784) only appear *after* a successful 1.5 s SOS hold and a GPS lookup (`home_screen.dart:650`). | Add a row of call chips on Home: one tap to dial, no GPS needed. | DECIDE (which numbers, order) |
| 3.5 | **"Not connected" banner takes the second-best slot** | The offline-official-alerts banner sits right under the level band. | Shrink it to a one-line status chip. Give that slot to real alerts when there are any. | UI |
| 3.6 | **Official alert cards** | Alerts are rendered as a `WarningBanner` holding one text blob: "level · sender · time \n headline" (`home_screen.dart:518-523`). | A real alert card: tier color stripe and icon, headline as the title, sender and time as meta, tap for details. | UI |
| 3.7 | **Water meter** | A plain bar with a tick. Only shows in demo mode. | Make a gauge with labeled zones (safe, watch, danger), a "limit" label on the tick, and a trend arrow. | UI |
| 3.8 | **No nearest shelter on Home** | The shelter is 2 taps away (Map tab, then the list). | Add a "Nearest shelter: X, 1.2 km, Directions" card. | UI |
| 3.9 | **SOS panel** | White panel, red disc, grey ring. Large but plain. On tablet it is a mostly empty white column (`width: 320`, `home_screen.dart:109`). | A stronger SOS design (red field or halo, clear hold instruction, ring in a contrasting color). On tablet, give the column purpose (SOS plus call chips). | UI |
| 3.10 | **SOS sheet** | Title, message box, one big red Call button, outlined SMS/Share, then a `Wrap` of text buttons for other numbers and Close. | Make clear steps: (1) call 1669, (2) send location via SMS/share, (3) other numbers as a grid of tiles. Show coordinates in a monospace "copy" field. | UI |
| 3.11 | **Short phones** | At 360x640 the gauge sits under the pinned SOS (`audit-after.md` N1). | Use a compact SOS panel under 700 dp height. | UI |

## 4. Sensors (`lib/screens/sensors_screen.dart`)

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 4.1 | **No history / trend** | Only the current value is shown (`sensors_390x844.png`). | Add a sparkline of recent readings with the limit line, and a trend arrow. | DECIDE (needs stored history) |
| 4.2 | **Sensor cards** | Icon, title, big number, limit text and status row, all left-stacked. Good, but repetitive. | Turn them into a gauge-style card: a progress-to-limit bar and a status chip in the top-right. | UI |
| 4.3 | **Live stations are bare `ListTile`s** | No tier color, no chip, no water bar (`sensors_screen.dart:276`). | Station cards with a tier chip (icon, word, color), depth, age, and "stale" styling. | UI |
| 4.4 | **Debug slider in the main flow** | Sits under the readings in debug builds (`sensors_screen.dart:89`). | Move it to a collapsible "Developer" section, or a long-press on the title. | UI |
| 4.5 | **Over-limit duplicated** | A red banner at the top *and* a red card for the same fact. | Keep one: the card, plus a summary chip at the top. | UI |
| 4.6 | **No station map link** | Stations and the map are separate. | Tapping a station opens it on the Map. | UI |

## 5. Map (`lib/screens/map_screen.dart`)

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 5.1 | **No "you are here"** | No user marker and no recenter button. | Add a location dot and a recenter floating button. | UI |
| 5.2 | **Fixed 3:2 split** | Map and list share the screen in a fixed ratio (`map_screen.dart:187-197`). | Use a draggable bottom sheet over a full-height map (peek showing the nearest shelter, expanded showing the list). | UI |
| 5.3 | **Offline state** | Flat grey placeholder plus a banner at the top (`map_390x844.png`). | A designed placeholder (grid/topo pattern) so markers still read as a map. | UI |
| 5.4 | **Markers** | 40 dp circles with icons. Sensor markers don't show their tier. | Pin shapes, sensor markers colored by tier, clustering at low zoom, a selected state. | UI |
| 5.5 | **Legend as its own row** | Takes a full row under the map (`map_screen.dart:315`). | A small floating legend chip on the map, or filter chips (Shelters / Sensors). | UI |
| 5.6 | **Attribution** | Shows "flutter_map \| © OpenStreetMap contributors" in a white bar. | Keep the OSM credit (required) but style it small and translucent in a corner. | UI |
| 5.7 | **Shelter list** | Plain rows: icon, name, capacity, chevron. | Cards with distance first, capacity, and a one-tap Directions button. Highlight the nearest one. | UI |
| 5.8 | **Sensor tap** | Shows a snackbar with the name only. | A sheet with the reading, tier and time, like shelters. | UI |

## 6. Report (`lib/screens/report_screen.dart`)

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 6.1 | **Category dropdown** | A hidden choice behind a tap (`report_screen.dart:195`). | 4 large icon chips/tiles. One tap, visible at once, better with one hand. | UI |
| 6.2 | **Ragged button row** | Camera, Gallery and Add-location wrap into an uneven 2+1 layout (`report_390x844.png`). | One "Attach" row of equal tiles: photo, gallery, location. Show attached state on each tile. | UI |
| 6.3 | **Photo preview** | A full-width 160 dp image, with no remove or replace. | A thumbnail with remove and replace. | UI |
| 6.4 | **Location shown as raw coordinates** | Plain text `13.75631, 100.50177`. | A location chip with a tiny map or "Location added ✓", with coordinates as secondary. | UI |
| 6.5 | **Save sits mid-screen** | The button is between the form and the saved list. | Use a sticky bottom Save, or split into form and "My reports". | UI |
| 6.6 | **Saved reports** | Cards with no actions. They can't be deleted, shared or exported. | A swipe or menu with delete and share. A detail view. | DECIDE (delete/share behavior) |
| 6.7 | **Form ↔ list on one scroll** | A long single page. | Two segments or tabs: "New report" and "Saved (n)". | UI |

## 7. Guide (`lib/screens/guide_screen.dart`)

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 7.1 | **Undifferentiated accordion** | 8 identical cards (`guide_390x844.png`). Flood, earthquake and first-aid are mixed together. | Group them: Before / During / After / First aid, with section headers or category tiles. | UI |
| 7.2 | **Step text** | Steps are inline "1. …" text (`guide_screen.dart:66-78`). | A step layout: numbered circles, one step per block, key words in bold. | UI (wording stays yours) |
| 7.3 | **No search** | — | Add a search field, or at least jump-to-category. | UI |
| 7.4 | **Urgent topics not prioritized** | CPR and bleeding are as hard to reach as "before flood". | Put an "Emergency first aid" quick-access row at the top, with large tiles. | UI |
| 7.5 | **Detail view** | Expansion inside the list. Long topics push everything around. | Open a topic as its own page, with large text and a "call 1669" button on first-aid pages. | UI |

## 8. About (`lib/screens/about_screen.dart`)

| # | What | Direction | Tag |
|---|---|---|---|
| 8.1 | Plain text and `ListTile`s under a stock `AppBar`. | Visually separate the disclaimer as a callout. Show sources as cards with license chips. Add version info and the app mark. | UI (wording is a draft pending legal review) |

## 9. Responsive / tablet

| # | What | Evidence | Direction | Tag |
|---|---|---|---|---|
| 9.1 | **Tablet Home** | The content column ends at about 40% of the height. The SOS column is mostly empty (`home_tablet-820x1180.png`). | Two-column dashboard: level and alerts on the left; SOS, call chips and nearest shelter on the right. | UI |
| 9.2 | **Content cap** | `ContentWidth` caps at 640 dp, so tablets show a narrow strip on Sensors, Report and Guide. | Use 2-column grids for sensor cards, guide tiles and report list on wide screens. | UI |

---

## Constraints any redesign inherits

- No new packages (`PRODUCT.md`): no charting, animation or icon libraries. Sparklines and illustrations must be `CustomPaint` or bundled assets.
- State stays `ChangeNotifier` / `ListenableBuilder`.
- Safety, first-aid and disclaimer wording is yours: layout may change, words may not without asking.
- Every state is icon + text + color. Taps ≥ 48 dp. Body ≥ 16 sp. Works at 1.5x text with Thai diacritics.
- Contrast pairs are asserted in `test/design_test.dart`. Any new token (especially a dark theme) needs a test entry.
- All 13 goldens in `test/goldens/` will need regenerating.

## Checked and rejected

I checked the skill's `--design-system` suggestion for "emergency alert app" and rejected it. It suggested a web landing-page pattern, Inter + Playfair Display, a pink background and red as the primary color. None of that fits:
- Inter has no Thai glyphs.
- Red as primary would collide with DANGER and SOS, which must stay the only red things on screen.

The useful part was its style category, "Accessible & Ethical" (high contrast, large text, visible focus, reduced motion), which the current tokens already follow.

## Decisions only you can make

1. **Direction**: keep the "flood gauge board" look and push it further, or choose a new visual direction?
2. **Night theme**: build a dark theme (recommended, given the night/rain use case), or stay light-only?
3. **Navigation**: keep 5 tabs, or merge Sensors into Home and add a Settings tab (language, About)?

Smaller decisions after that: quick-dial numbers on Home (3.4), sensor history storage (4.1), and report delete/share (6.6).

### Decided (2026-11-17)

1. **Direction: "Public notice"**, a new direction that replaces "flood gauge board":
   - Warm paper background, ink-black text and 2–3 px black frames, square corners.
   - The level is a framed block with a 4-step level meter underneath ("level 2 of 4").
   - The SOS is a framed red block.
   - It reads like a printed government warning poster.
2. **Theme: light and dark**, following the phone's setting. Each has its own contrast tests.
3. **Navigation: 4 tabs plus settings.** The tabs are Home, Map, Report and Guide. Sensor readings move into a details section on Home. Language and About move behind a settings button.
