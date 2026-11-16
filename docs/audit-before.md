# Audit before redesign

Method: Impeccable native audit (code-level, from `lib/`) plus a Home critique (Assessment A only; detector not applicable on native). The Impeccable engine could not be downloaded in this session, so no `impeccable context`, `signals` or `concept-seed` ran; the reference playbooks were read directly. No emulator was used: findings come from source and from the contrast arithmetic shown.

Contrast figures are computed from WCAG relative luminance of the exact colors in the code.

## Audit Health Score

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 1 | No `Semantics`, several contrast failures, 44 dp marker targets |
| 2 | Performance | 3 | Whole-screen rebuild every 2 s, otherwise light |
| 3 | Appearance & Theming | 1 | Colors hard-coded in 5 files, no tokens, seed-generated Material default look |
| 4 | Platform Conformance | 2 | Material 3 navigation is right; phone bottom bar kept on tablets |
| 5 | Adaptivity | 1 | No tablet or landscape layout, unbounded content width |
| **Total** | | **8/20** | **Poor** |

## Platform Conformance Verdict

Pass on structure (NavigationBar, Material components, system Back untouched). Fail on identity: the look is the default Material 3 seed theme with raw red/orange/green cards (`main.dart:35`, `alert_level.dart:5-8`), nothing specific to a flood or earthquake app. Fail on adaptivity: the phone bottom bar is kept on every width (`main.dart:78`).

## Executive Summary

- Audit Health Score: **8/20 (Poor)**
- Findings: **P0: 0 · P1: 9 · P2: 6 · P3: 3** (18 total)
- Top issues: SOS fires on a single tap and sits mid-scroll; no theme tokens or Thai-first font; contrast failures on the Watch card; no Semantics; no offline/empty/error states.

## Findings

| ID | Sev | Screen | Issue | file:line | Fix |
|----|-----|--------|-------|-----------|-----|
| F01 | P1 | Home | SOS triggers on a single tap: accidental activation, no haptic, no progress | `home_screen.dart:219` | Press-and-hold about 1.5 s with a progress ring and haptics |
| F02 | P1 | Home | SOS is not dominant or thumb-reachable: it sits below three cards in a scrolling list, 180 dp | `home_screen.dart:104-117`, `:216` | Anchor SOS at the bottom of the screen, largest element |
| F03 | P1 | All | Hard-coded colors: `Color(0x…)` and `Colors.*` with no token layer | `alert_level.dart:5-8`, `main.dart:35`, `home_screen.dart:37,64,75,113,149-159,179,222-226`, `map_screen.dart:70,72,86,88`, `sensors_screen.dart:28,36,103-108`, `report_screen.dart:217` | Move all color, type, spacing, radius, elevation to `ThemeExtension` tokens in `lib/theme/` |
| F04 | P1 | All | No Thai-first font, no type scale: system default, body 14 sp, fixed `fontSize: 34` and `48` | `main.dart:33-36`, `home_screen.dart:155,229` | Bundle Sarabun, body at least 16 sp, theme text roles |
| F05 | P1 | Home, Sensors, Report | Contrast failures: white on `0xFFEF6C00` is about 3.1:1; white70 sub-label on the card; `Colors.orange` text on white about 2.2:1; `0xFFC62828` on `0xFFFFCDD2` about 4.0:1 | `alert_level.dart:6`, `home_screen.dart:141-159`, `home_screen.dart:75`, `report_screen.dart:217`, `sensors_screen.dart:103-105` | Pick pairs at 4.5:1 or better and test them |
| F06 | P1 | All | No `Semantics`: map markers are an unlabeled `GestureDetector`, alert and sensor values have no merged labels | `map_screen.dart:36`, `home_screen.dart:135-165`, `sensors_screen.dart:104-` | Label markers, alert level, sensor values and the SOS control |
| F07 | P1 | Map | Offline gives silent blank tiles with no message | `map_screen.dart:65` | Calm offline banner plus retry, shelter list stays the main content |
| F08 | P1 | Report, Map | States are not designed: empty report list is a plain line, empty shelter cache shows nothing, GPS failure is orange text | `report_screen.dart` ("No reports yet."), `map_screen.dart:95-107`, `report_screen.dart:217` | Designed empty, error and offline states |
| F17 | P1 | All | No Thai copy at all although Thai is the primary language | all screens | Needs Thai translations; wording is the user's call (open by constraint) |
| F09 | P2 | Home | Only three alert levels exist; the design needs Safe / Watch / Warning / Danger | `alert_level.dart:5-8`, `sensor_service.dart` level getter | Style tokens for four levels; the model/service rule is a product decision |
| F10 | P2 | All | Bottom NavigationBar on tablet and landscape; content stretches full width; map and list squeezed in landscape | `main.dart:78`, `map_screen.dart:51-95` | NavigationRail at 600 dp and up, max content width, side-by-side map and list |
| F11 | P2 | Map | Marker tap targets are 44 dp | `map_screen.dart:34-35` | 48 dp minimum |
| F12 | P2 | Home, Sensors | Every 2-second tick rebuilds the whole screen list, also in hidden tabs | `home_screen.dart:100-104`, `sensors_screen.dart:16-20`, `main.dart:68` | Scope `ListenableBuilder` to the changing cards |
| F13 | P2 | Home | Latest-warning banner is always orange, has no time or source, and competes with the alert card | `home_screen.dart:111-114`, `mock_data.dart:14` | Neutral info style, label that it is mock data |
| F14 | P2 | Sensors | The demo slider is overwritten by the 2-second timer; behavior outside the redesign scope | `sensor_service.dart:12-14` | Not changed (behavior); label it as demo only |
| F15 | P3 | All | Reduce-motion is never read; no motion tokens | `guide_screen.dart:19` | Motion tokens at 150-250 ms, honor `disableAnimations` |
| F16 | P3 | Home, Report, Sensors | Dates come from `DateTime.toString().substring(…)` | `home_screen.dart:54`, `report_screen.dart:245`, `sensors_screen.dart:60` | Left as is (no `intl` package allowed) |
| F18 | P3 | Startup | First frame waits for SharedPreferences and a shelter write | `main.dart:18-19` | Left as is (behavior) |

## Home critique (design review only)

Method: design review only (detector not applicable, native platform).

**Specificity verdict.** Interchangeable. The Home screen is three stock cards over a red button; any app could wear it.

**Nielsen scores (Home):** visibility of status 2, match with real world 2, user control 2, consistency 2, error prevention 1, recognition 3, flexibility n/a, minimalism 2, error recovery 2, help n/a. **Total 16/32 (50%): Acceptable.**

**Top 5 Home UX problems**
1. SOS is not the dominant control. It sits below the alert card, water card and banner, in the middle of a scrolling list (`home_screen.dart:104-117`).
2. SOS fires on one tap (`home_screen.dart:219`): a pocket touch or a shaking hand starts a dialog, and there is no haptic or progress to confirm intent.
3. The Watch card is white text on orange at about 3.1:1, and its sub-label is white70, so the most important sentence ("Stay alert…") is the hardest to read in rain or at low brightness (`home_screen.dart:141-159`).
4. The warning banner is orange whatever the level, has no time or source, and fights the alert card for attention (`home_screen.dart:111-114`).
5. Nothing says the data is mock or how old it is, and nothing says offline is fine: a scared user cannot tell whether to trust the screen.

**Persona red flags.** *Casey (one-handed, interrupted):* SOS is mid-scroll, not in the thumb zone. *Sam (screen reader):* the alert card reads as unrelated text fragments with no level announcement. *Jordan (first-timer, scared):* English-only, no hint that SOS shares a location.

Questions skipped: this is a baseline file, not an interactive critique round; the user's brief already sets the direction.

## Systemic patterns

- No token layer: color, type and spacing decided per widget in five files.
- No state design: every data view shows only the happy path.
- No accessibility pass: zero `Semantics` widgets in `lib/`.

## Positive findings

- Navigation is Material 3 `NavigationBar` with five labeled destinations.
- Every GPS, camera and storage failure path is caught and shown as text (`location_service.dart`, `storage_service.dart`).
- Offline support is real: shelters, reports and the guide need no network.
