# Figma prompt: Disaster Alert & Rescue

Paste everything below the line into Figma (Make / First Draft / AI) or follow it by hand. Built from `DESIGN.md`, `PRODUCT.md` and the screens in `lib/screens`.

---

Design a mobile app called **"Disaster Alert & Rescue"**: a flood and earthquake safety app for scared residents, often outdoors at night, one-handed, low brightness, weak or no signal. Thai is the primary language, English secondary. A person must find the alert level and the SOS control in under two seconds.

## Creative direction: "The Posted Public Notice"
The app looks like a public notice pinned to a board: square blocks framed in black ink, ruled into sections, heavy Thai type. NOT soft rounded cards, NOT pastel banners, NOT a round red hero button.
- **Corner radius 0 everywhere.** The only round shapes: sensor map markers (discs) and the "you are here" dot.
- **No shadows, no gradients, no blur.** Depth comes from strokes only.
- **No brand accent colour.** Ink (near-black) is the accent: primary buttons, selected tabs, selected tiles and tags are ink blocks with paper-coloured text.
- Green, yellow, orange, red appear ONLY for alert levels, SOS, over-limit readings, and the first-aid call button.
- Every state shows icon + word + colour, never colour alone.

## Frames and set-up
- Phone frames at 390 x 844 (also a 360 x 640 small-phone check). 8 px spacing grid. Screen gutters 16.
- Build every screen in **two variants: Day board and Night board** (use Figma variables with Light and Dark modes).
- Content max width 640 on wide screens. Wide layout (>= 600 wide) swaps the bottom bar for a labelled left rail.

## Font
**Sarabun** (Google Fonts; supports Thai). Weights 400 / 500 / 700. Line heights are generous so Thai tone marks are never clipped.

| Style | Size / weight / line height | Use |
|---|---|---|
| Display Large | 48 / 700 / 1.1 | "SOS" |
| Display Small | 36 / 700 / 1.2 | level word, sensor values, emergency numbers |
| Headline Medium | 28 / 700 / 1.25 | tab/screen titles |
| Headline Small | 24 / 700 / 1.3 | title on pushed pages |
| Title Large | 22 / 700 / 1.3 | dialog title |
| Title Medium | 18 / 700 / 1.4 | section labels, guide step numbers |
| Title Small | 16 / 700 / 1.4 | row and tile titles |
| Body Large | 18 / 400 / 1.5 (500 for level advice) | guide steps, advice |
| Body Medium | 16 / 400 / 1.5 | body, banners |
| Body Small | 16 / 400 / 1.5, muted colour | captions, "demo data" lines |
| Label Large | 16 / 700 / 1.4 | buttons |
| Label Medium | 14 / 700 / 1.4 | nav labels, tags |
| Label Small | 14 / 500 / 1.4, muted | meter steps, map credit |

Body text never below 16. Only labels use 14.

## Colour variables

**Day board**: Ground `#F2EDE2` · Surface `#FBF8F1` · Ink `#16140F` · Ink muted `#4A463D` · Hairline `#BDB4A1` · Pressed `#E3DBCA` · Offline bg `#E6E0D2` · Error bg `#F6DEDA` · Danger ink `#A3101A`

**Night board**: Ground `#14130F` · Surface `#1F1D18` · Ink `#EFE8D8` · Ink muted `#B8B09F` · Hairline `#6F6858` · Pressed `#2E2B24` · Offline bg `#26241E` · Error bg `#3A1A17` · Danger ink `#FF9A90`

**Alert tiers (same on both boards)**
| Tier | Icon | Field | Text on field | Tier as text on Day / Night |
|---|---|---|---|---|
| SAFE (ปลอดภัย) | check circle | `#1D6B3A` | `#FFFFFF` | `#1D6B3A` / `#86D49F` |
| WATCH (เฝ้าระวัง) | eye | `#F2C200` | `#16140F` | `#6E5300` / `#F2C200` |
| WARNING (เตือนภัย) | warning triangle | `#B93D0B` | `#FFFFFF` | `#A33508` / `#FFA270` |
| DANGER (อันตราย) | octagon | `#B3121C` | `#FFFFFF` | Danger ink of the board |

SOS red = `#B3121C`. Selection highlight = `#F2C200` at 40%.

## Strokes
- **Rule 1 px**: dividers, empty meter cells.
- **Frame 2 px ink**: every block, tile, input, outlined button, banner, section-label rule.
- **Heavy 3 px ink**: under every screen header, above the bottom nav bar and sheets, around the level notice, the SOS block and the current meter step.
Stroke is drawn **inside/in front of** the content.

## Components (build as Figma components with variants)

1. **NoticeFrame**: surface fill, 2 px ink frame, 16 padding, 0 radius.
2. **NoticeTile** (button): same as frame, min height 48. Variants: default / pressed (Pressed fill) / **selected** (ink fill, ground-coloured text and icons). Used for emergency numbers, nearest shelter, guide tiles, report category choices (2 per row, equal height).
3. **ScreenHeader**: Headline Medium title on one line (shrinks, never wraps), optional trailing gear icon (48 x 48 target), 3 px ink rule underneath.
4. **SectionLabel**: Title Medium text sitting on a patch of ground colour over a full-width 2 px ink rule.
5. **NoticeTag**: small ink block, ground-coloured Label Medium text, padding 2 / 8. E.g. "NEAREST", "SAMPLE, NOT A REAL SHELTER".
6. **Buttons** (all square):
   - Primary: ink fill, ground text, Label Large, height 56, side padding 24. Disabled: hairline fill, muted text.
   - Outlined: surface fill, 2 px ink frame, height 48.
   - Text button: ink, 2 px underline, 48 target.
   - Call-danger: red `#B3121C`, white text, height 56 (the only red filled button besides SOS).
   - Segmented: height 56, framed, selected segment = ink block.
7. **Text field**: surface fill, 2 px ink border, 16 padding. Focus: 3 px border. Error: Danger-ink border and message. Muted label that floats in Label Large.
8. **Warning banner**: framed, icon + message + optional text action. Variants: Info (surface, ink frame) · **Offline** (Offline bg, hairline frame, cloud-off icon, never red) · Error (Error bg, danger-ink frame, error icon).
9. **LevelMeter (signature component)**: 4 equal cells 20 tall, 8 apart (Safe, Watch, Warning, Danger). Cells up to current level filled in their own tier colour; the rest are surface. Current cell has a 3 px frame and its word in Label Medium; others 1 px frame and Label Small. Null level = all empty.
10. **SegmentedGauge**: same cells (10 of them) for a measured value: ink fill up to the value, a heavy 3 px ink "post" at the safe limit, cells past the limit filled red.
11. **SOS block**: full-width, red `#B3121C`, 3 px ink frame, height 112 (88 on short screens), "SOS" Display Large white on the left, hold hint (Title Small white, "Press and hold" / "กดค้างไว้") beside it. A 10 px white progress bar along the foot (show 0%, 60%, 100% states). Loading variant: indeterminate bar + "Finding your location…". 3 px ink rule below.
12. **Bottom navigation bar**: height 76, ground fill, **3 px ink rule on top**. 5 tabs, labels always visible: Home (home icon), Call (phone), Map (map), Report (edit/clipboard), Guide (book). Selected = square ink indicator with ground-coloured filled icon + Label Medium 700; unselected = outline icon, muted label weight 500.
13. **Level notice** (Home): one 3 px ink frame holding three stacked parts: (a) ink bulletin strip with area + posted time in ground colour (Label Medium); (b) tier field with 48 px tier icon, "Level 1 of 4", the level word in Display Small, advice in Body Large 500, all in the tier's on-colour; (c) surface strip with LevelMeter and a source line ("Source: demo data").
   - Build all 4 tier variants + a **No data** variant: Offline-bg field, sensor-off icon, "No live data", "Do not assume it is safe".
14. **Reading block**: title with icon, status word with check/octagon icon, value in Display Small (tabular figures), SegmentedGauge, safe-limit text. **Over-limit variant**: Error bg, 3 px danger-ink frame, value in danger ink. "Demo data, not live" caption with update time.
15. **Map markers**: shelters = 40 x 40 square, surface fill, 2 px ink frame, ink icon; sensor stations = 40 px ink discs; "you are here" = ink dot inside two rings. Each has a 48 px tap area.
16. **Dialog / bottom sheet**: surface, 2-3 px ink frame (sheet: 3 px ink rule on top + handle), only these overlays may have a subtle elevation.

## Screens (design each in Day and Night)

### 0. Startup notice
Ground background, centred NoticeFrame (3 px frame, max width 420): app name "Disaster Alert & Rescue" (Headline Medium), 6 px ink progress bar at about 60%, caption "Preparing the offline map…".

### 1. Home (tab 1)
Pinned top: ScreenHeader "Home" with gear, then **SOS block** directly under it (3 px rule beneath). Scrollable below, in order:
- Level notice, show the **SAFE** version as the main frame (area "Bangkok (sample area)", posted time, "Level 1 of 4", "SAFE", advice, meter, "Source: demo data").
- Reading blocks: Water level "80 cm" with gauge and "Safe limit 150 cm"; Vibration "0.1 g", limit 0.5 g.
- SectionLabel "Nearest shelter" then a NoticeTile: "City Hall Shelter", capacity 300, distance, NEAREST tag, chevron.
- SectionLabel "Official notices": two or three framed rows (title, source, time).
Extra frames: Home with WATCH, WARNING, DANGER, and No-data variants; Home with offline banner; Home with an over-limit reading.

### 2. SOS sheet (after hold completes)
Bottom sheet, 3 px top rule. Call first: big NoticeTiles for 1669, 191, 1784. Second: ready-made message box "I need help. My location: 13.7563, 100.5018" with a primary **Share message** button. Also a GPS-failure dialog: "Could not read GPS. Use last saved position?" with Primary + Outlined buttons.

### 3. Call (tab 2)
ScreenHeader "Call". One large NoticeTile per number, full width: number in Display Small, service name beneath:
- **1669**: Emergency medical (การแพทย์ฉุกเฉิน)
- **191**: Police (ตำรวจ)
- **1784**: Disaster hotline, DDPM (สายด่วนนิรภัย ปภ.)
Each with a phone icon on the right. Footnote banner: "Tapping opens the dialer. You still press call."

### 4. Map (tab 3)
Full-bleed light, mostly monochrome map (same light map on both boards) with 5 square shelter markers, 3 round sensor markers, you-are-here dot. Gear button top-right in a framed square. Small legend (square = shelter, disc = sensor) and map credit (Label Small) at the bottom left.
Bottom sheet over the map (3 px top rule + handle): segmented button **Shelters | Sensors**.
- Shelters tab: list of framed rows: City Hall Shelter (300), Green Hill School (200), Community Sports Hall (450), Sunrise Temple Hall (150), North District Clinic (80) with a "SAMPLE, NOT A REAL SHELTER" tag.
- Sensors tab: River Gate Station, Old Bridge Station (water level), Hillside Vibration Station; each row has a tier cell on the right (icon + word on tier colour) or an empty Offline-bg cell with "–".
Extra: sheet expanded, offline banner with "Try again" button, wide layout with a 340 px side column instead of the sheet.

### 5. Report (tab 4)
ScreenHeader "Report damage". Form:
- SectionLabel "Category": 2 x 2 grid of NoticeTiles: Flooded road (flood icon), Damaged building, No power, No water. Show one selected (ink block). Validation error state: "Please choose a category".
- SectionLabel "Note": multi-line text field.
- SectionLabel "Photo": two outlined buttons "Camera" / "Gallery"; attached-photo preview in a framed square.
- SectionLabel "Location": outlined button "Use my location" (loading: "Finding…"), address text field, coordinates caption, error banner variant.
- Primary button "Save report" (56 high).
- SectionLabel "Saved reports (0)": empty banner "No reports yet. Reports you save stay on this phone only, work without internet, and are not sent to anyone yet." Also a variant with 2 saved report tiles (category icon, note, time, address).

### 6. Guide (tab 5)
ScreenHeader "Guide". SectionLabel "First aid" with large NoticeTiles (2 per row): Severe bleeding, CPR basics (adult), Burns, Broken bones. SectionLabel "Disaster topics" with full-width rows: Before a flood: get ready · During a flood · Evacuation checklist · Earthquake safety (chevron right).
**Guide detail page** (pushed, app bar with back arrow + Headline Small title and 3 px rule): numbered steps, each a 32 x 32 ink square with the number (Title Medium, ground colour) beside the step in Body Large. First-aid pages end with the red **Call 1669** button.

### 7. Settings (pushed)
App bar "Settings". SectionLabel "Language": segmented **ภาษาไทย | English**. SectionLabel "Theme": segmented **Phone (auto icon) | Light | Dark**. SectionLabel "About": NoticeTile with info icon, "About and disclaimer", chevron.

### 8. About (pushed)
App bar "About". App name, version, short description, a framed disclaimer notice (e.g. "Data in this app is demo data. In an emergency call 1669 or 1784."), data credits (OpenStreetMap / Protomaps).

## Interaction notes (for prototype links)
- Hold SOS 1.5 s: bar fills, then sheet appears; a short tap does nothing.
- Tab switching keeps each tab's state.
- Gear in every tab header opens Settings. Tap a shelter opens it on the map.
- Field colour of the level notice cross-fades 250 ms when the level changes; keep other motion at 150-200 ms.

## Accessibility rules to respect in the design
Text contrast 4.5:1, UI 3:1, every control at least 48 x 48 (primary buttons 56), body text 16 or more, layouts must survive 1.5x text scale with Thai diacritics unclipped, no information by colour alone.

## Deliverables in Figma
1. Variables: colour (Day/Night modes), spacing (4, 8, 16, 24, 32, 48), stroke (1, 2, 3), radius (0), type styles.
2. Component library page with all components above and their variants.
3. Screens page: all screens x Day/Night, plus the tier, offline, error and empty states.
4. A prototype wiring the 5 tabs, the SOS hold, Settings and Guide detail.
