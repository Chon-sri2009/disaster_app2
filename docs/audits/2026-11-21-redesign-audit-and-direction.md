# Redesign audit and direction brief (2026-11-21)

Status: PROPOSAL. No code changed. Waiting for the owner's yes (roadmap Phase R).
Method: hallmark's order (audit the defaults, pick one direction from the real job, one idea per screen, critique at the end). Its web-only tooling (CSS stamp, sloplint, stock photos, hero rules) does not apply to Flutter and was not used. CLAUDE.md wins where they differ.

Read for this audit: `CLAUDE.md`, `DESIGN.md`, `PRODUCT.md`, `lib/theme/*`, `lib/widgets/soft_ui.dart`, `level_meter.dart`, `home_screen.dart` (first 560 lines), and the committed golden PNGs for Home (calm, danger), Call, Guide, Report, Map. NOT yet read line by line: `map_screen`, `report_screen`, `settings`, `about`, `alert_detail`, `alert_history`, `flood_history_card`, `sensor_readings`, `sos_hold_button` bodies. They are read at their own task. Goldens were not re-run; the committed PNGs were viewed.

## 1. Audit: slop tells actually present

| # | Tell | Where | Why it hurts here |
|---|---|---|---|
| 1 | One white rounded shadowed card repeated for everything | `SoftCard` (`soft_ui.dart:6`) used 22 times; Home `_Board` stacks level, quick call, shelter, notices as four same-weight cards | The water level, the one thing that matters, has the same weight as "Quick call" (see `home_phone-390x844.png`) |
| 2 | Navy header band on every tab | `BrandHeader` (`soft_ui.dart`), identical in Call, Guide, Report, Map goldens | Same slab on every screen says nothing; it also costs 72 dp of a small screen |
| 3 | Icon in a tinted circle | `RoundChip` (Home quick call), `calls_screen.dart:65`, `guide_screen.dart:41,139`, `home_screen.dart:361`, `report_screen.dart:502`, raised Call circle `main.dart:335` | The stock "feature grid" mark; every service looks alike, so icons stop meaning anything |
| 4 | No weight hierarchy: almost everything is 700 | `app_theme.dart` text styles: 9 of 14 are w700; every card title is 18/700 (`SectionLabel`) | Titles, rows, buttons, numbers all shout equally |
| 5 | Soft shadow + 16 radius + pills + 24 sheets all at once | `AppRadius` lg/md/xl/pill, `cardShadow`, `StatusPill`, pill buttons | Four shape languages, none chosen |
| 6 | Left accent bar on rows | `AccentRow` (3 dp bar), Guide and Home rows | A common generated-UI device; the colour bar duplicates what the icon and word already say |
| 7 | Default Material parts | `NavigationBar` with indicator pill, `ExpansionTile` in `CollapsibleCard`, segmented buttons in Settings, stock `Icons.*` set | Looks like every Material 3 sample |
| 8 | Raised round centre tab | `main.dart:331-345` | Template trope; Call is not more important than Home's SOS |
| 9 | Level meter is four equal rounded segments | `level_meter.dart` | A progress bar; current level is only 10 dp taller than the filler |
| 10 | SOS as a glowing red card | `sos_hold_button.dart`, DESIGN.md "red glow" | Glow and ring are decoration; the hold progress is the only meaningful part |
| 11 | Eyebrow line above a title | `BrandHeader.eyebrow` ("Area not known yet" over the app name) | Small label stacked over a heading; also repeats the area line already in the level card |
| 12 | Dot-joined meta string | `home_screen.dart` source line "จากเซนเซอร์ชุมชน · อัปเดต …" | Separator is a tell; fix is layout (two lines), not wording |
| 13 | Sub-16 sp labels | `labelMedium/labelSmall` 14 sp (pills, meter words, nav labels) | Breaks the 16 sp hard rule; CLAUDE.md lists "14 sp vs 16 sp" as an open owner decision |
| 14 | Map bottom sheet with drag handle and segmented switch | `map_390x844.png` | Generic; shelters list cramped under the map |

What is NOT slop and stays: tier colours and their contrast (tested), icon + word + colour, 48 dp targets, Sarabun with even leading for Thai, press-and-hold SOS, calm offline tint, `context.tr` wording, tokens through `AppTokens`.

## 2. Direction brief: "Posted notice"

**Idea.** A flood warning should look like a posted notice and a river staff gauge, not a card app. The level is one slab that owns the top of Home. Everything else is plain text on the ground, separated by rules and space, not boxes. Shape is square and ruled; colour means state.

**Hierarchy: severity dominates.**
- Home top = the **level slab**: full width, edge to edge, no card, no shadow. Tier icon + the level word at 40 sp + advice line + a **vertical staff gauge** (four ticks, current tick marked, the rest outlined) down its left side. Quiet tiers (safe, no data) use the ground colour with a thick tier-coloured top rule; WARNING and DANGER fill the slab with the tier colour (existing rule, kept). WATCH: thick yellow top rule plus yellow icon block (loud threshold stays warning+danger unless you say otherwise, decision R-D3).
- "No data" is the neutral slab with the sensor-off icon and "No live data": never green, never red.
- SOS is a full-width square bar directly under the slab: solid danger red, "SOS" at 40 sp, hold progress is a filling bar along its base. No glow, no ring.
- Below: plain sections on the ground. A section = title (20/600), a hairline rule, rows. No cards.

**Type** (Sarabun, already bundled, SIL OFL, so no new font to approve; a different Thai face is optional decision R-D2).
- Scale: level word 40/700 · screen title 28/700 · section title 20/600 · body 17/400 · row title 17/600 · meta 16/400 muted · button 17/600. Nothing below 16 sp (this resolves the open 14 sp question in favour of 16: needs your yes, R-D1).
- Weight carries hierarchy: 700 only for the level word, SOS and screen title. Numbers (phone numbers, level) use tabular figures.
- Labels and tags: sentence case, untracked, no all-caps. Thai even leading kept.

**Colour.**
- Tiers unchanged in value and meaning: safe `#1D6B3A`, watch `#F2C200`, warning `#B93D0B`, danger `#B3121C`, each with its icon and word. Tier text-on-ground colours unchanged.
- Neutrals: flat ground (day `#F4F6F8`-class, night deep navy kept) with ink text and hairline rules. No white cards, no shadows. New values only inside `app_palette.dart`, each added to the contrast test.
- Brand blue stays for actions and links only (One-Blue Rule). The navy header band is removed: screen titles sit on the ground.
- Offline/no data: quiet neutral tint, cloud/sensor-off icon, never red.

**Shape and spacing.** Slabs and rules are square-edged. Controls 8 dp radius. One pill left: none (status uses a square-cornered tag with icon + word). Spacing scale kept (4/8/16/24/32/48); sections 32 apart, rows 16, side gutter 16. Content cap 640 stays.

**Iconography.** Same Material icon set (no package), but bare: 24 dp icon beside text, no tinted circle, no raised nav button. Tier icons keep their different shapes. Call tab is one of five equal tabs; selected tab = ink label + 3 dp top rule instead of a pill.

**Call, Report, Guide, Map.**
- Call: three numbered rows, number 36/700, service name, a clear "Call" text button (48 dp); ruled list, no cards.
- Report: one column of ruled fields and choice rows (checked state = check icon + filled box); save is a full-width 56 dp bar.
- Guide: ruled index list; first-aid group headed by a danger rule, others by an ink rule; no ExpansionTile card.
- Map: map full height; list as a plain sheet with square top edge; the switch is two text tabs with an underline.

**Motion.** 200 ms colour change on the level slab; SOS hold fill; folding. Nothing else, nothing decorative. All through `context.motion` (zero under remove-animations).

## 3. Hard-rule check

Icon + word + colour on every state · 48 dp targets · 16 sp minimum · 1.5× text with Thai unclipped (goldens at 1x and 1.5x per screen) · offline never red · no wording change · no new package or font · no official look · no change to `alert_rules`, `alert_service`, `sensor_service`, `backend/`, `firmware/`.

## 4. Owner decisions needed before code

- **R-D1** Minimum text 16 sp everywhere (drops the 14 sp labels). Recommended: yes.
- **R-D2** Keep Sarabun only (recommended), or approve an additional bundled Thai face (name it; licence check follows).
- **R-D3** WATCH stays "calm with a yellow rule" (recommended) or becomes a filled slab like WARNING.
- **R-D4** The dot-joined source line may become two lines (layout only, same words).
- **R-D5** Remove the navy header band and the raised Call tab (both change the app's whole look).
