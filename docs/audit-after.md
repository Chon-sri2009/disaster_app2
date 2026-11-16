# Audit after redesign

Method: same as `audit-before.md` (Impeccable native audit from source, design review only; the engine could not download, so no detector or context run). Evidence is `flutter analyze`, `flutter test` (31 tests), and screenshots rendered by `test/design_test.dart` and `test/offline_map_test.dart` into `test/goldens/`. **No emulator, device, TalkBack or profiler run was done**: haptics, real GPS, screen-reader speech, frame times and the in-app map were not exercised.

Commands run last: `flutter analyze` → "No issues found!"; `flutter test` → "All tests passed!" (31).

## Audit Health Score

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 3 | Tap-target, label and text-contrast guidelines pass on all 5 tabs; not tried with TalkBack |
| 2 | Performance | 3 | Home rebuilds scoped; Sensors still rebuilds the whole list every 2 s; not profiled |
| 3 | Appearance & Theming | 3 | Tokens complete for screens; no night theme; dead hard-coded colors left in `alert_level.dart` |
| 4 | Platform Conformance | 3 | Material 3 bar/rail by size; no Dynamic Color, no dark scheme |
| 5 | Adaptivity | 3 | Checked at 360x640, 390x844, 820x1180, 844x390 and 1.5x text; no foldable or multi-window check |
| **Total** | | **15/20** | **Good** (was 8/20) |

## Executive Summary

- Audit Health Score: **15/20 (Good)**, before 8/20.
- Findings still open or partly open, by residual severity: **P0: 0 · P1: 1 · P2: 6 · P3: 4** (11). Before: P0 0 · P1 9 · P2 6 · P3 3 (18).
- Open P1: F17 (no Thai copy).
- Remaining items need decisions from you: Thai wording, a fourth alert level in the model, a night theme.

## Remaining and new findings

| ID | Sev | Screen | Issue | file:line | Fix |
|----|-----|--------|-------|-----------|-----|
| F17 | P1 | All | No Thai copy; all strings English | all screens | Provide Thai wording (including safety text, which I did not touch) |
| F08r | P2 | Report | A corrupt saved-reports list still loads as empty with no message | `services/storage_service.dart:82-93` | Show an error state; needs a service change |
| F09 | P2 | Home | The four tiers are styled but the sensor service emits only three | `models/alert_level.dart:4-17`, `services/sensor_service.dart:34-40` | Add a Warning rule to the model and service |
| F12 | P2 | Sensors | The whole list rebuilds every 2 s, also while the tab is hidden | `screens/sensors_screen.dart:20`, `main.dart:79` | Scope the builder; profile on a device |
| F13r | P2 | Home | The warning text has no time or source | `data/mock_data.dart:14`, `screens/home_screen.dart:150` | Needs real data fields |
| F14 | P2 | Sensors | The timer overwrites the demo slider; only labeled "demo only" | `services/sensor_service.dart:17-19`, `screens/sensors_screen.dart:78-82` | Behavior unchanged on purpose |
| N1 | P2 | Home | At 360x640 the water gauge sits partly under the pinned SOS panel; the value is visible, the gauge needs a scroll | `screens/home_screen.dart:136-140`, `test/goldens/home_phone-360x640.png` | Compact SOS panel on very short phones |
| F03r | P3 | Model | `AlertLevel` still holds unused hard-coded `Color` and icon fields | `models/alert_level.dart:5-17` | Remove them (model change) |
| F15 | P3 | All | Dialog and page transitions use Flutter defaults; reduce-motion verified only in the gauge, SOS ring and guide list | `widgets/sos_hold_button.dart:60`, `theme/app_tokens.dart:168` | Check on a device |
| F16 | P3 | Dates | Dates still come from `DateTime.toString().substring()` | `screens/home_screen.dart:54`, `screens/report_screen.dart` | Needs `intl` (not allowed) |
| F18 | P3 | Startup | First frame waits for storage | `main.dart:19-20` | Behavior unchanged on purpose |

## Finding status

| Finding | Status | Evidence |
|---|---|---|
| F01 SOS fires on one tap | **fixed** | Press-and-hold ring with haptics at `widgets/sos_hold_button.dart:28-60`; test "a quick tap does nothing, a 1.6 s hold opens the dialog" passes |
| F02 SOS not dominant / thumb-reachable | **fixed** | Pinned panel `screens/home_screen.dart:108-140`; `test/goldens/home_phone-360x640.png`, `home_360x640_scale1.5.png`, `home_landscape-844x390.png` |
| F03 Hard-coded colors | **partly** | `grep "Color(0x\|Colors\.\|fontSize" lib/screens lib/widgets` returns nothing; raw hex only in `theme/app_palette.dart`; leftover in `models/alert_level.dart:5-17` (F03r) |
| F04 No Thai-first font / type scale | **fixed** | Sarabun in `pubspec.yaml` + `assets/fonts/`; body 16 sp asserted in test; Thai tone marks intact at 1.5x in `test/goldens/thai_sample_scale1.5.png` |
| F05 Contrast failures | **fixed** | Token test asserts every text pair at 4.5:1 and UI pair at 3:1; `textContrastGuideline` passes on all 5 tabs |
| F06 No Semantics | **fixed** (guideline-tested) | Labels on SOS, level band, water meter, sensor cards, markers, banners; `labeledTapTargetGuideline` passes on all 5 tabs; not run with TalkBack |
| F07 Silent offline map | **fixed** | `screens/map_screen.dart:120-160`; `test/offline_map_test.dart` waits for failed tiles and finds the banner and "Try again"; `test/goldens/map_offline_390x844.png` |
| F08 States not designed | **partly** | Empty report and empty shelter states, GPS error banners, offline banner built; corrupt-storage case open (F08r) |
| F09 Only three tiers | **partly** | Four styled tiers `theme/app_tokens.dart:99-131`, `test/goldens/alert_levels.png`; data emits three (open) |
| F10 No tablet/landscape layout | **fixed** | Rail at 600 dp wide and 480 dp tall `main.dart:73-110`, content cap `widgets/content_width.dart`; no overflow at 4 sizes x 2 text scales (test "layouts do not overflow") |
| F11 44 dp marker targets | **fixed** | `screens/map_screen.dart:58-59` uses 48 dp; `androidTapTargetGuideline` passes on Map |
| F12 Whole-screen rebuilds | **partly** | Home builders scoped `home_screen.dart:186,257`; Sensors unchanged; not profiled |
| F13 Warning banner | **partly** | Neutral info style, placed right after the level; "mock data" label on the meter; no time on the warning (F13r) |
| F14 Slider overwritten by timer | **partly** | "For demos only…" text added `sensors_screen.dart:78-82`; behavior unchanged |
| F15 Reduce motion / tokens | **partly** | `AppMotion` 150-250 ms, `context.motion()` used in gauge, ring, guide list; defaults elsewhere |
| F16 Date formatting | **open** | Unchanged |
| F17 No Thai copy | **open** | Needs your wording |
| F18 Startup | **open** | Unchanged |
| N1 Water gauge under pinned SOS at 360x640 | **open** (new) | `test/goldens/home_phone-360x640.png` |

Counts: fixed 8, partly 7, open 4 (F16, F17, F18, N1).

## Top 5 Home problems, re-checked

1. SOS dominance: fixed, pinned and largest.
2. Single-tap activation: fixed, hold 1.5 s plus haptics.
3. Contrast of the level band: fixed, on-color pairs at 4.5:1 or better.
4. Warning banner: partly, restyled and reordered, still lacks a time.
5. Mock/stale and offline clarity: partly, "mock data, updated hh:mm:ss" shown; Home itself has no offline banner because it needs no network.

## Checks you asked for

| Check | Result | Evidence |
|---|---|---|
| Semantics labels (icons, SOS) | pass in tests | guideline tests; no TalkBack run |
| Contrast 4.5:1 text, 3:1 UI | pass | token test, `textContrastGuideline` |
| Focus and reading order | not tested on a device | Home order is level, warning, water, SOS |
| No overflow at 1.5x text | pass | 4 sizes x 1.0x and 1.5x |
| 360x640, 390x844, tablet, landscape | pass in widget tests | goldens above |
| Map scroll smooth | **not measured** | no profiler or device run |
| const constructors | pass | `flutter analyze` clean under `flutter_lints` |
| Rebuild storms | partly | see F12 |
| `flutter analyze` / `flutter test` | pass | commands above |

## Notes on what changed outside the redesign

- `dart format` ran over `lib/` and `test/`, so models, services and data files got formatting-only edits (no logic). There is no git history here to diff against.
- `SosHoldButton` changes SOS from tap to press-and-hold, as the brief requires.
- The shelter and warning text, first-aid text and all other copy are unchanged.
