# Developer context (for the coding agent)

Compact briefing to read at session start, after `CLAUDE.md`. It does not replace CLAUDE.md or the roadmap; it records state, invariants and traps that are easy to miss. Written 2026-11-23. Verify any file or symbol named here before relying on it.

Read order: `CLAUDE.md` → roadmap (`docs/superpowers/plans/2026-11-18-disaster-app-roadmap.md`, Part 1 for status, Part 2 for tasks) → this file → `DESIGN.md` before UI work. Do not restate `docs/DEVELOPMENT_PLAN.md`. Do not edit `PRODUCT.md` or `DEVELOPMENT_PLAN.md`.

## State of the tree

- Branch `redesign-public-notice`, 47 commits, **not pushed**. Last commit `f7dc313` (Thai shelter names, basemap labels follow app language).
- **Working tree is dirty and large:** Phase R redesign (`lib/theme/*`, `lib/widgets/notice_ui.dart` new, every screen), R-F1…R-F10 safety fixes, goldens, new tests, `docs/audits/`. Not committed. Do not commit unless the owner asks. Review golden PNG diffs before any commit.
- `backend/sensors.db` and `backend/stations.json` are local files; confirm git-ignore before staging.
- Windows + CRLF: do not mass-reformat.

## Architecture in five lines

1. Phone reads two HTTPS JSON snapshots: `GET /snapshot` (sensors) and `GET /alerts` (TMD CAP, normalised). Plain HTTP is refused by the app.
2. `backend/sensor_ingest.py` is the only server process (stdlib, SQLite). It owns `/ingest` (HMAC, replay guard), `/snapshot`, `/health`, `/alerts`, `/flood-recurrence` (GISTDA, key server-side).
3. `backend/tmd_cap.py` parses one CAP file (pure); `tmd_poller.py` builds the snapshot and keeps last good data; `capture_cap.py` records real fixtures into `backend/fixtures/cap/`.
4. App services (`lib/services/`) take injectable fetcher and clock. `alert_rules.dart` is pure and safety-critical; `alert_service.dart` caches, ages and notifies; `sensor_service.dart` same for sensors.
5. State is `ChangeNotifier` + `ListenableBuilder` only. Strings go through `context.tr(th:, en:)`, Thai first.

## Invariants (break one and a test must fail)

- **No false Safe.** `SensorService.level` returns null when stale or empty. A stale Safe station shows the neutral no-data tag, not green (`sensor_readings.dart`, R-F1). Only an alert escalates (`AlertRules.combine`); an official Safe carries no information.
- **Age comes from the data's own timestamp.** Both services age from the snapshot `generatedAt`, never from download time. Sensors: explicit-UTC string required; missing or invalid `generatedAt` rejects the whole body (last good data keeps aging). Future time is not clamped.
- **Clock slack:** `clockBackSlack` 1 min for sensors; `AlertService.futureSlack` 5 min for alerts (owner, 2026-11-23). Beyond slack a future time is stale. Sensors: phone clock >1 min behind server means sensor Safe never shows (fails safe, owner-visible).
- **Staleness must notify on time alone.** Both services tick (sensors 30 s, alerts 2 min refresh plus tick) and call notify only when stale/visible set changes. A hung read is bounded by one 15 s deadline in `httpGetText` (`http_get.dart`). `_disposed` guards stop notify-after-dispose.
- **Visible alert** = `status == Actual`, not Cancel, not replaced via `references`, not past `effectiveExpiry` (6 h default if no expiry, UI says "no expiry given"). `skippedFiles > 0` in the snapshot means stale.
- **Matching:** polygons win; province codes only for polygonless alerts (open owner decision: polygons-win vs polygon-or-province). Alert history never feeds any level.
- **Coordinates:** CAP polygon strings are `lat,lon`; snapshot and GeoJSON are `[lon, lat]`. Every conversion has a test. Time: UTC stored, Asia/Bangkok shown.
- **Contract file** `test/fixtures/alerts_snapshot.json`: regenerate with `cd backend && UPDATE_CONTRACT=1 python -m unittest test_tmd_poller`. `alert_contract_test.dart` reads it.

## Traps

- Never log a raw GISTDA response or URL (the key is in the links). Never put keys in `lib/` or `--dart-define`.
- Backend: stdlib only. Never trust the device or the agency file: validate, skip the bad item, keep last good data. One bad CAP file must not hide the rest.
- `design_test.dart` rewrites its PNGs and compares nothing. It is not proof. CI skips it. Contrast pairs in it do assert.
- Flutter pinned **3.47.9**. Do not bump in a feature task.
- `StationStatus.fromJson` uses `DateTime.parse`: one bad `readingTime` rejects the whole snapshot (safe side, loses good stations). Recorded, not fixed.
- R-F10(d) open: `_dataTime` accepts a zone-less time as local while sensors require UTC (comes out stale; inconsistent only).
- Home tab labels in Thai wrap inside the word at 360 dp / 1.5× text (R3 note): owner decision pending (shorter label or four tabs).
- `RuledRow` drops its tap action from the screen-reader tree (R2 follow-up).
- Pill/tag text is 14 sp against the 16 sp rule (owner decision pending).
- Firmware has never been compiled or run. Uplink is signed HTTP POST, not MQTT.
- Old widgets (`SoftCard`, etc.) were scheduled for removal in R10; check `lib/widgets/` before reusing any.

## Wording rule (hard rule 3)

Never write or reword Thai or English safety copy, advice lines, Guide, disclaimer or emergency numbers. New strings: mark `// DRAFT`, list them for the owner. Known DRAFT: Home area tags, alert detail, history, `ถูกแทนที่ด้วยประกาศใหม่` (approved 2026-11-23), H1/H2/H4a strings. 191, 199, 1155 are unconfirmed (`emergency_numbers.dart`).

## Task routing

- **Opus:** advises on hard tasks (design, edge cases, traps; no edits), reviews safety-critical code and the whole branch.
- **Sonnet:** implements with the task text, the Global Constraints and exact interfaces. Fresh reviewer per task.
- **Haiku:** lookups, grep, renames, running a command.
- Main session coordinates; it does not implement. Tick the roadmap checkbox when a step finishes. A new idea goes into the roadmap and needs the owner's yes before code.

## Open work, by readiness

| Ready now | After owner yes or input |
|---|---|
| No unbuilt Phase H task is ready. H2 and H4a are built and committed (the roadmap still shows their commit step unticked); H4c (Google Maps first) is built, tests pass, and `emergency_launcher.dart` is still uncommitted. Tick the roadmap boxes when the owner confirms. | H1 (decision 15) · H3 (decision 9) · H4b, H5–H9 (decisions 10–14) · Phase C (host route) · Phase D (numbers, reviewers, privacy) · F (hardware) · G |
| Owner wording and decisions listed in the roadmap §1.6 and Phase R notes | |

Phase C is the first real blocker: without a deployed HTTPS backend nobody is warned, whatever the app does. It also owns: cache and rate limit on `/flood-recurrence` (unauthenticated, spends the GISTDA quota), kill switch, runbook, live TMD run, latency table, then push.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test                          # includes goldens, local only
cd backend; python -m unittest discover
cd backend; python sensor_ingest.py   # port 8080, LAN, no TLS
cd backend; python simulate.py --key <key> --scenario flood
```

CI set: every `test/*_test.dart` except `design_test.dart`. Last recorded: analyze clean, 115 Flutter tests, 134 backend tests (backend re-run 2026-11-23 OK; Flutter not re-run when this was written).

## Process for a task

Failing test → see it fail → minimal code → see it pass → analyze → small commit message `feat(scope): …` (commit only when asked). Comments say why, short, plain English, in the style of `alert_rules.dart`. Report what is not verified.
