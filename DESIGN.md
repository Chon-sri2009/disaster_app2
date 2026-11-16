# Design

Surface: the whole app, Operate mode, light theme only. Tokens live in `lib/theme/`; screens read them through `context.tokens` and `Theme.of(context)`.

## Direction

**Flood gauge board.** The look comes from enamel flood-gauge signs and public warning boards: flat fields of one color per state, thick ink-on-light type, no shadows, no gradients. Scene: a frightened resident, one hand, at night in rain, phone at low brightness, so everything is high contrast, large, and flat.

Direction note: the Impeccable engine could not download in this session, so no concept roll or direction page ran. This direction was chosen from the brief and the scene above, not rolled. Re-roll on request.

## Color

One accent (deep water blue) for navigation and primary actions; neutrals tinted cool; one solid color per alert tier. Raw hex exists only in `lib/theme/app_palette.dart`.

| Token | Hex | Use |
|---|---|---|
| ground | `#F3F6F8` | screen background |
| surface | `#FFFFFF` | cards, nav, dialogs, SOS panel |
| ink | `#0B1B26` | body text, icons, gauge tick |
| inkMuted | `#44566A` | captions (7.0:1 on ground) |
| outline | `#6B7D8C` | input borders (3.9:1) |
| hairline | `#D3DCE3` | dividers, gauge track |
| accent / onAccent | `#0B5A7A` / `#FFFFFF` | buttons, selected nav, links (7.5:1) |
| accentSoft | `#D3E6EF` | nav indicator |
| safe / onSafe | `#14683A` / `#FFFFFF` | SAFE (6.9:1) |
| watch / onWatch | `#F2C200` / `#0B1B26` | WATCH (about 10:1) |
| warning / onWarning | `#C2410C` / `#FFFFFF` | WARNING (5.2:1) |
| danger / onDanger | `#B3121C` / `#FFFFFF` | DANGER, SOS, over-limit (7.0:1) |
| infoBg, offlineBg, errorBg | `#E3EEF4`, `#E6EAEE`, `#F9E3E4` | calm banner tints, text is ink |

Alert tiers never rely on color alone: SAFE = check circle, WATCH = eye, WARNING = triangle, DANGER = octagon with X, each with its word. Contrast pairs are asserted in `test/design_test.dart`.

## Typography

Sarabun (SIL OFL, bundled in `assets/fonts/`, weights 400/500/600/700), Thai-first. Every style uses `leadingDistribution: even` and line height 1.3 to 1.5 so Thai tone marks are not clipped (checked at 1.5x in `test/goldens/thai_sample_scale1.5.png`).

| Role | Size / weight | Use |
|---|---|---|
| displayLarge | 56 / 700 | SOS label |
| displaySmall | 36 / 700 | alert word, sensor value |
| headlineMedium | 28 / 700 | screen titles, water value |
| titleLarge/Medium/Small | 22/18/16 · 600 | dialog title, row titles |
| bodyLarge / bodyMedium / bodySmall | 18 / 16 / 16 | body, captions |
| labelLarge | 16 / 600 | buttons |
| labelMedium / labelSmall | 14 | nav labels, map credit |

## Space, shape, elevation, motion

- Spacing, 8-dp grid: `AppSpace` xs 4 (half step), sm 8, md 16, lg 24, xl 32, xxl 48.
- Radii: `AppRadius` sm 8, md 16, lg 24.
- Elevation: flat. Only dialogs and snackbars lift (`AppElevation.overlay` 3). Cards use a 1 px hairline instead of a shadow.
- Motion: 150 / 200 / 250 ms (`AppMotion`). Used for the gauge fill, SOS ring release and list expansion. `context.motion()` returns zero when the phone's remove-animations setting is on.
- Tap targets: `AppSize.tapTarget` 48 dp minimum; primary buttons 56 dp.

## Components

- **Level band (Home):** full-width field in the tier color, icon + area + level word + advice, all in the tier's on-color. Announced as one live-region label.
- **Water meter:** value, flat gauge bar, ink tick at the safe limit, caption "mock data, updated hh:mm:ss".
- **SOS (Home):** the largest control, pinned at the bottom (phone) or right (wide). Press and hold 1.5 s with a progress ring, medium haptic on press, heavy haptic on completion. A short tap does nothing. Screen-reader users confirm with the long-press action.
- **Status banner (`WarningBanner`):** info, offline (calm slate, cloud icon, optional "Try again"), error. Never red for offline.
- **Sensor card:** plain with a hairline border when within the limit; solid danger fill with an X icon and "OVER LIMIT" when over.
- **Navigation:** bottom `NavigationBar` under 600 dp wide or under 480 dp tall; a labeled `NavigationRail` otherwise. Content is capped at 640 dp wide.
- **Map:** accent house markers for shelters, ink sensor markers, a legend, a shelter list beside (wide) or below (phone), offline banner when tiles fail.

## States

| View | Loading | Empty | Offline | Error |
|---|---|---|---|---|
| Home | sync data, none needed; SOS shows "Finding your location…" | n/a | works offline | GPS failure dialog with saved-position fallback |
| Sensors | n/a (first reading is immediate) | n/a | works offline | over-limit banner + card |
| Map | tile placeholder | "No shelters are saved on this phone yet…" | calm offline banner + retry | tile errors handled |
| Report | "Finding location…" button | "No reports yet…" | works offline | GPS and photo errors as banners / snackbar |
| Guide | n/a | n/a | works offline | n/a |

## Not built, on purpose

- **Night theme.** The brief allows it only if it passes the same audit; it was not built or audited.
- **Fourth alert tier in the data.** The Warning tier is styled (`AlertTier.warning`) but the model and sensor service emit only Safe / Watch / Danger. Adding it changes the model and service.
- **Thai copy.** All strings are English; Thai wording is the user's decision.

## Rules for future work

- No color, size, spacing, radius or duration literals in screens: add a token first.
- One accent. A new color needs a state it explains.
- Every state is icon + text + color. Every control is at least 48 dp and has a screen-reader label.
