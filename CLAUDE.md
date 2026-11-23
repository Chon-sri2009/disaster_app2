# CLAUDE.md — Disaster Alert & Rescue

Thai-first Flutter app + small Python backend + ESP32 sensors. Goal: warn people in Thailand about floods faster than slow official channels, offline-safe, never falsely "Safe".

## Work only inside the plan

- The plan is [`docs/superpowers/plans/2026-11-18-disaster-app-roadmap.md`](docs/superpowers/plans/2026-11-18-disaster-app-roadmap.md). Research and verified sources: [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) (do not restate or re-research it).
- Do tasks in the roadmap's order (Task 0 → 5, then Phases B–D, F, G as the owner unblocks them; there is no Phase E). Tick the checkbox in the roadmap as each step finishes.
- A new idea, feature or fix **outside** the roadmap: add it to the roadmap and get the owner's yes **before** writing code. Bugs found while working on a task are fixed inside that task only if they block it; otherwise they go in the roadmap.
- Phases B–D, F, G are outlines. Turn one into exact tasks (writing-plans skill) only when its blocker is cleared by the owner. Never guess a blocked input (keys, permissions, Thai wording, tier mappings).
- Use TDD: failing test, see it fail, minimal code, see it pass, small commit. Do not commit unless the owner asks, and never push.

## How work is run: subagent-driven, three model tiers (owner's choice, 2026-11-18)

- **Opus 5.5 (`model: "opus"`)**: hard tasks only. Design decisions, the safety-critical alert logic (CAP parsing, staleness, cancel/update handling), whole-branch review, and anything the roadmap marks hard or that fails twice at Sonnet.
- **Sonnet 5.5 (default, `model: "sonnet"`)**: carries out most work: implements each roadmap task, follows Opus's decisions, and does whatever the owner commands directly.
- **Haiku 5.5 (`model: "haiku"`)**: small helper jobs only: finding files, grepping, listing, renaming, formatting, boilerplate, running a command and reporting output.
- Flow per task: Sonnet implements, a fresh reviewer checks it (Opus for safety-critical tasks, Sonnet otherwise), then the next task. The main session coordinates and does not implement. Each subagent gets the task text, the Global Constraints and the exact interfaces it consumes, nothing else.
- Hard tasks in Phase A: Task 2 (CAP parsing) and Task 3 (poller keeps last good data) were implemented by Opus and reviewed by Sonnet. Tasks 0, 1, 4, 5 went to Sonnet. The final whole-branch review is Opus. Haiku does lookups and fixture housekeeping.
- **From Phase B on (owner's instruction, 2026-11-18): Opus advises, Sonnet implements.** For a hard task, first dispatch Opus to read the task and return written advice and exact instructions (design, edge cases, tests to write, traps), without editing files. Then dispatch Sonnet with the task text plus Opus's instructions to implement. Reviews stay as above (fresh reviewer; Opus for the final whole-branch review). Tasks 7 and 8 were implemented by Opus directly before this rule.

## Hard rules (safety and product)

1. **Never a false Safe.** Stale, offline, faulty or missing data is "no data", never Safe. Only an alert escalates a level (`AlertRules.combine`).
2. **Observations, not orders.** Sensors say "Community sensor, not an official gauge". The app and backend never issue official warnings or evacuation orders. Sensors do not raise area alerts (decision D15) until a season of comparison data exists.
3. **Wording is the owner's.** Do not reword Guide, first-aid or safety text, advice lines or the disclaimer. Thai copy is written or approved by the owner. Draft text must be marked `DRAFT`.
4. **Secrets stay on the server.** Keys live in `backend/.env` (git-ignored). Never in `lib/`, `--dart-define`, logs or commit messages. Never log a raw GISTDA response or its URL (the key is in the links).
5. **Coordinates stay on the phone** except where the owner has approved it (open question: Nominatim address lookup and flood-history requests send GPS out; see roadmap §1.5).
6. **Every state is icon + word + colour** (never colour alone), tap targets ≥ 48 dp, text ≥ 16 sp, works at 1.5× text scale, offline is a normal state (never red because of connectivity). Read `PRODUCT.md` and `DESIGN.md` before UI work.
7. **Time and place:** UTC in storage and snapshots, Asia/Bangkok in the UI; WGS84; CAP polygons are `lat,lon`, snapshots are `[lon, lat]`.
8. **No new Flutter packages, no Firebase/push, no new backend services without the owner's explicit yes.** Backend is Python standard library only.
9. **Do not edit `PRODUCT.md`** (the owner edits it; it is out of date on packages, offline tiles and push). Do not edit `docs/DEVELOPMENT_PLAN.md` (it is the dated spec).
10. **No official look or name.** No government emblems, no "T-Alert" or "Thai Disaster Alert" naming, no wording that implies endorsement.

## Status snapshot (2026-11-18)

- Done: 5 tabs (Home, Map, Call, Report, Guide) + Settings + About; Thai/English via `context.tr`; 4 tiers; SOS hold + call/SMS/share; MapLibre with bundled Bangkok pack and ~110 shelters; local reports; sensor backend (`/ingest`, `/snapshot`, `/health`) with signed readings; app live/demo sensor modes; official-alert rules and cache (`AlertRules`, `AlertService`); CI.
- Phase A done and reviewed (local commits on `redesign-public-notice`, not pushed): GISTDA flood history landed; TMD CAP pipeline (`backend/tmd_cap.py`, `tmd_poller.py`, `capture_cap.py`, real fixtures in `backend/fixtures/cap/`, `GET /alerts`, `--tmd-feed`); app ages alerts from the snapshot `generatedAt`, refreshes every 2 min, treats `skippedFiles > 0` as stale, and reads `ALERT_SNAPSHOT_URL`. Contract file: `test/fixtures/alerts_snapshot.json` (regenerate: `cd backend && UPDATE_CONTRACT=1 python -m unittest test_tmd_poller`).
- Scope (owner, 2026-11-18): **floods are the focus.** Phase E (other hazards) is deleted; do not add PM2.5, quake, landslide, heat or fire work. Host is **Cloudflare**; the deploy route is still undecided.
- Phase B done and reviewed (local commits, not pushed): province boundary bundle `assets/boundaries/th_provinces.json` (77 provinces, COD-AB CC BY-IGO, built by `backend/build_provinces.py`), `areaCodes` in `/alerts`, `AlertRules.matches`/`areaOf` (polygons win; province codes only for polygonless alerts), Home area tags, alert detail screen, alert history (never feeds any level). Proof: `flutter analyze` clean, 115 Flutter tests (CI set), 134 backend tests. New wording is DRAFT. Open owner decisions: polygons-win vs polygon-or-province; new tag/detail/history wording; 14 sp pill text vs the 16 sp rule.
- Persona audit 2026-11-19 (`docs/audits/2026-11-19-bangkok-flood-persona-audit.md`, simulated, verdict 35/100 blocked): roadmap Phase H added. Ready: H2 (SOS sheet opens at once), H4a ("not sent" line on Report). H1 waits for the owner's yes (roadmap 1.6 item 15); H3–H9 wait for decisions 9–14.
- Next gaps (roadmap Phases C, D, F, G, owner-blocked): HTTPS hosting on Cloudflare and a live run against TMD, push, province/district targeting, release blockers below. Deferred review items are listed in the roadmap and the final report.
- Proof as of 2026-11-18 (after Phase A): `flutter analyze` clean; 51 Flutter tests (all but `design_test.dart`) and 107 backend tests pass. `design_test.dart` only rewrites its review PNGs (they are screenshots, not comparisons) and was not used as proof; firmware never compiled.
- Release blockers: 191/199/1155 unconfirmed (`lib/data/emergency_numbers.dart`), Guide has no expert sign-off, no privacy notice, no deployed HTTPS backend, `PRODUCT.md` stale.

## Commands

```bash
flutter pub get
flutter analyze
flutter test                                              # includes goldens; run locally
flutter test $(ls test/*_test.dart | grep -v design_test) # what CI runs
cd backend && python -m unittest discover                 # all backend tests
cd backend && python sensor_ingest.py                     # port 8080, LAN, no TLS
cd backend && python simulate.py --key <key> --scenario flood
flutter run --dart-define=SENSOR_SNAPSHOT_URL=https://host/snapshot
flutter run --dart-define=ALERT_SNAPSHOT_URL=https://host/alerts   # after Task 5
```

- Flutter is pinned to **3.47.9** (CI). Newer stable deprecates `package:flutter/material.dart`; do not bump inside a feature task.
- The app accepts only `https://` snapshot URLs. Use a TLS proxy for local live tests.
- Golden PNGs in `test/goldens/` are rewritten by `flutter test`: review the diff, never commit blindly.
- Windows + PowerShell/Git Bash: line endings warn (CRLF); do not mass-reformat files.

## File map

| Path | What |
|---|---|
| `lib/main.dart` | App start, services wiring, tab shell, map-loading gate |
| `lib/screens/` | `home`, `map`, `calls`, `report`, `guide`, `settings`, `about`, `flood_history_card` |
| `lib/services/` | `alert_rules` (pure rules), `alert_service` (cache + age), `sensor_service`, `location_service`, `place_lookup`, `emergency_launcher`, `offline_map`, `storage_service` (shared_preferences) |
| `lib/models/` | `alert_level` (safe/watch/warning/danger), `official_alert`, `station_status`, `shelter`, `damage_report`, `flood_history` |
| `lib/data/` | `bangkok_shelters`, `emergency_numbers`, `guide_data` (owner's wording), `mock_data` (demo only) |
| `lib/l10n/` | `context.tr(th:, en:)` helpers; Thai is the default language |
| `lib/theme/`, `lib/widgets/` | Tokens (`AppTokens`), soft-card UI, SOS hold button |
| `backend/` | `sensor_ingest.py` (server), `gistda.py`, `simulate.py`, tests; Phase A adds `tmd_cap.py`, `tmd_poller.py`, `capture_cap.py` |
| `firmware/` | ESP32 water-level sketch and README (uplink is signed HTTP POST, not MQTT) |
| `assets/maps/` | Bundled Bangkok PMTiles pack, glyphs, sprites |
| `docs/` | Plans, audits, owner checklists (`INPUTS_NEEDED.md`, `OWNER_TODO.md`) |

## Data contracts

- Sensor snapshot: `GET /snapshot` → `{"stations": [{id, name, band, status, waterCm, readingTime}]}`; `band` = safe/watch/warning/danger/unknown. Only `status == "ok"` counts.
- Alert snapshot (Phase A): `GET /alerts` → `{"generatedAt", "alerts": [{id, sender, status, msgType, level, headline{lang:text}, sent, expires|null, references[ids], polygons[[ [lon,lat] ]]}]}`. The app ages alerts from `generatedAt`.
- Visible alert = `status == "Actual"`, not Cancel, not replaced via `references`, not past `effectiveExpiry` (6 h default if no expiry, and the UI says "no expiry given").
- Official source of truth for Thai warnings: TMD CAP feed (the only source with an explicit reuse statement). Other agencies need the owner's written permission first (D5).

## Conventions

- State: `ChangeNotifier` + `ListenableBuilder` only. Services take injectable fetcher/clock so tests need no network.
- Comments say *why*, short, plain English. Match the existing style (see `alert_rules.dart`).
- Every user-facing string goes through `context.tr(th:, en:)` with Thai first. Check wrapping at 1.5× in goldens.
- Python: stdlib only, pure functions for parsing, injected `get`/`clock` for tests. Never trust the device or the agency file: validate, skip bad items, keep last good data.
- Keep tasks small: one deliverable, one test cycle, one commit message (`feat(scope): …`).

## When blocked

Stop and ask the owner, naming the exact input needed (file, key, wording, decision number D#). Do not invent Thai text, emergency numbers, severity mappings, agency endpoints or licence claims. Record the blocker in the roadmap.
