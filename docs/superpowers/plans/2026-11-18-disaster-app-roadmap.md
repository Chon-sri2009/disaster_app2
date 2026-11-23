# Disaster Alert & Rescue: Roadmap and Implementation Plan

> **Status 2026-11-18: Phase A (Tasks 0-5) is implemented and reviewed on branch `redesign-public-notice` (local commits, not pushed). Final review fixes (headline crash, Test-status Cancel, skippedFiles, auto refresh, live generatedAt check, contract test) are in. Still to do by the owner: run the backend against the live TMD feeds behind HTTPS and look at the app; look at the 8 UI-polish screenshots; confirm the severity-to-tier mapping. Phases B-G wait for owner inputs.**

> **Update 2026-11-19: the Bangkok flood persona audit ([`docs/audits/2026-11-19-bangkok-flood-persona-audit.md`](../../audits/2026-11-19-bangkok-flood-persona-audit.md), 100 simulated residents, verdict 35/100 "blocked" for a real flood tomorrow) added Phase H (panic-readiness, Tasks H1–H9) below. The owner asked for the plan to be rewritten from that report. The audit is simulated reasoning from code, not user research; a 5-person phone session is still owed (H0). H2 and H4a are ready to build; H1 waits only for the owner's yes in 1.6 item 15; H3–H9 wait for the decisions in 1.6 (items 9–14). Phase C (hosting and delivery) is now the first blocker for any real use: without it no one can be warned, whatever the app does.**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the app from "working prototype with real sensor plumbing" to a release that tells a person in Thailand about an official warning for their location faster than they would otherwise hear it, offline-safe and never falsely "Safe".

**Architecture:** A Flutter app (phone) reads small JSON snapshots over HTTPS from one small Python backend (standard library only). The backend turns each source (community water sensors today, TMD official alerts next) into one snapshot shape. The phone caches every snapshot and always shows how old it is.

**Tech Stack:** Flutter 3.47.9 / Dart 3 / Material 3, `ChangeNotifier` state; Python 3.12 stdlib backend with SQLite; ESP32 firmware (Arduino); MapLibre with a bundled PMTiles map pack.

**Spec:** [`docs/DEVELOPMENT_PLAN.md`](../../DEVELOPMENT_PLAN.md) (verified sources, hazards, agency terms, decisions D1–D15; written 2026-11-12). It is the research spec and is **not restated here**. Product rules: [`PRODUCT.md`](../../../PRODUCT.md), [`DESIGN.md`](../../../DESIGN.md). Owner inputs: [`docs/INPUTS_NEEDED.md`](../../INPUTS_NEEDED.md), [`docs/OWNER_TODO.md`](../../OWNER_TODO.md).

## Global Constraints

- Never show a false Safe: stale, offline, faulty or missing data is "no data" (unknown), never Safe. Only an alert can escalate the level.
- Sensors report observations ("Community sensor, not an official gauge"). The app never issues an official warning or an evacuation order.
- Safety, first-aid and Guide wording is owned by the owner. Do not reword it. Thai text is written or approved by the owner.
- API keys and secrets stay on the server (`backend/.env`, git-ignored). Never in `lib/`, never in a `--dart-define` that ships.
- Backend: Python standard library only, one process, no new services without the owner's yes.
- Flutter is pinned to **3.47.9** in `.github/workflows/ci.yml`. Do not bump it inside a feature task.
- No new Flutter packages, no Firebase, no push without the owner's explicit yes (PRODUCT.md "no new packages"; INPUTS_NEEDED §6 says "later").
- Coordinates: WGS84. CAP polygons are `lat,lon`; the snapshot and GeoJSON are `[lon, lat]`. Every conversion has a test.
- Times: store and exchange UTC ISO 8601; show Asia/Bangkok.
- Release blockers: emergency numbers 191, 199, 1155 are unconfirmed on an official page; Guide has no expert sign-off; no privacy notice; PRODUCT.md is out of date.
- CI runs every `test/*_test.dart` except `design_test.dart` (goldens are local-only, drawn on the author's OS).

## Review Focus

Failure modes the spec implies but earlier tests do not exercise, most likely first:

1. **Dead poller looks fresh.** `AlertService` measures age from the phone's download time. If the TMD poller dies and the backend serves an old file, the phone shows "no alerts" as current. Expect: staleness from the snapshot's own `generatedAt`. (Tasks 3, 5)
2. **Update/Cancel never cancels.** CAP `<references>` are `sender,identifier,sent` triples, but `AlertRules.visible` compares plain ids. A cancelled alert would stay on screen. Expect: the poller converts references to plain ids. (Task 2)
3. **Polygon axis swap.** CAP `lat,lon` vs snapshot `[lon,lat]`. A swap puts the warning on another continent and shows nothing locally. (Task 2)
4. **Alert with no polygon matches nobody.** `AlertRules.levelAt` uses polygons only; an alert that carries only a province `geocode` is silently invisible on Home. Expect: it is kept, counted in the snapshot, and listed (not dropped); province-level matching is Task B1. (Tasks 2, 3)
5. **One bad file hides all alerts.** A malformed or huge CAP file, or one 404 in the feed, must skip that file only and keep the rest. (Task 3)

## How to read this document

- **Part 1** is for the owner, in plain words: what is done, what is not, what is needed from you.
- **Part 2** is the build plan. Phase A is written as exact tasks. Phases B–G are outlines with their blockers; they get written as full tasks when their blocker clears (never guess).
- Rule for agents: only work on tasks listed here. A new idea is added to this file and approved by the owner first.

---

# Part 1 — For the owner

## 1.1 What the app is today

Thai-first (English switch) Flutter app with five tabs (Home, Map, Call, Report, Guide), plus Settings and About. The goal from your own brief: beat slow government alert delivery with your own sensors and, next, official alerts delivered faster to the right place.

Verified today (2026-11-18): `flutter analyze` clean; 32 Flutter tests pass (everything except the golden-screenshot file `design_test.dart`, which was **not** run); 28 backend tests pass. Eight golden images are modified in the working tree and need your eyes before they are saved.

## 1.2 Done (works and is tested)

| Area | What works | Where |
|---|---|---|
| Language, theme | Thai default, English switch, day/night themes, 4 alert tiers (Safe, Watch, Warning, Danger) with icon + word + colour | `lib/l10n/`, `lib/theme/` |
| Home | Alert band, location in words (never raw coordinates), press-and-hold SOS | `lib/screens/home_screen.dart`, `lib/widgets/sos_hold_button.dart` |
| SOS and calling | Share-sheet text with GPS and UTC offset; call 1669 / 191 / 1784; SMS composer; directions to a shelter. The user always presses call or send | `lib/services/emergency_launcher.dart`, `lib/screens/calls_screen.dart` |
| Map (offline) | MapLibre with a bundled Bangkok map pack (`assets/maps/bangkok-20261113.pmtiles`), about 110 Bangkok shelters (BMA directory and school/temple roster), sensor markers, loading screen | `lib/screens/map_screen.dart`, `lib/data/bangkok_shelters.dart` |
| Report | Photo + GPS + note saved on the phone only | `lib/screens/report_screen.dart` |
| Guide | Offline first-aid and evacuation topics (your wording) | `lib/data/guide_data.dart` |
| About | Disclaimer (4 of the 5 required points; draft wording) and data-source credits | `lib/screens/about_screen.dart` |
| Official-alert engine (app side) | Rules for Actual-only, expiry, Update/Cancel, point-in-polygon, "official alert only escalates"; snapshot cache with age | `lib/services/alert_rules.dart`, `alert_service.dart` |
| Sensor backend | Signed `POST /ingest` (HMAC, replay guard), `GET /snapshot`, `GET /health`; server rechecks range, jump, stuck values; stale/offline = "unknown" | `backend/sensor_ingest.py` |
| Sensor in app | Live mode (`SENSOR_SNAPSHOT_URL`), debug-only demo mode, release build shows "No live data" | `lib/services/sensor_service.dart` |
| Firmware | ESP32 + ultrasonic sketch, local alarm, offline buffer, signed uplink. **Not yet compiled or run on hardware** | `firmware/` |
| Project hygiene | App id `app.disasteralert.th`, CI (analyze + tests + backend), README | `.github/workflows/ci.yml` |

## 1.3 In progress (written, not committed)

GISTDA flood-history ("this spot flooded N of the last years"): backend client and route (`backend/gistda.py`, `/flood-recurrence`), app service and card, tests. Needs a GISTDA API key from you (`backend/.env`, see `.env.example`). Also uncommitted: edits to Home, Map, About, `soft_ui.dart`, `main.dart`, 8 golden PNGs, and a stray `sensors.db` in the project root that should be git-ignored. **Finish and commit this before Phase A** (Task 0).

## 1.4 Not done

| # | Item | Why it matters | Blocked by |
|---|---|---|---|
| 1 | **Official alert feed (TMD)**: nothing produces alerts. `AlertService` is built with no URL (`lib/main.dart:127`), so Home can never show an official alert today | This is the core promise | Nothing. Approved ("OK to write the poller code now") and the tier mapping needs your confirmation (see 1.6) |
| 2 | Backend deployed with HTTPS | The phone refuses non-HTTPS; today it runs on a LAN | Host chosen: **Cloudflare** (owner, 2026-11-18). Open: how (see Phase C), budget, who deploys |
| 3 | Push notifications when the app is closed | A warning app that needs to be open is weak | You: Firebase project and package approval (said "later", D2) |
| 4 | Targeting by province/district/sub-district | Today matching uses only polygons | Boundary data (COD-AB, CC BY-IGO) and a decision on size |
| 5 | ~~More hazards~~ **Dropped 2026-11-18 (owner): floods are the focus** | | |
| 6 | Emergency numbers 191, 199, 1155 confirmed | Release blocker | An official page or your phone call |
| 7 | Guide and safety text reviewed by a medical and a disaster-management expert | Release blocker | You: two reviewers |
| 8 | Privacy notice and consent screen (Thai + English) | Needed before store release | You: data controller name, counsel |
| 9 | Real shelter data checked on the ground, with "last confirmed" dates | Today's list is from directories | You: pilot area and DDPM contact |
| 10 | Sensors on real hardware, then a season next to an official gauge | No sensor may drive an alert before this | You: hardware, a site |
| 11 | Crash reports (opt-in only, no location) | You chose opt-in | A package decision |
| 12 | Burmese, Lao, Khmer UI | Migrant workers | Native translators, extra fonts (Phase 3) |
| 13 | Alert history, alert detail screen | Trust and audit | After Phase A |
| 14 | Rescue coordination (SOS to a server, rescuer view) | Highest-risk feature | A partner who will really respond, legal review |
| 15 | PRODUCT.md is out of date (says "no new packages", "OSM tiles blank offline", "no push") | Agents read it as law | **You edit it** (agents must not) |
| 16 | **The app does not know where the user is until SOS or Report is used** (audit F1, F3): no nearest shelter, no area-matched notices, no age on the saved position | Biggest first-minute failure in the audit | Task H1 (after your yes, decision 15; wording is DRAFT) |
| 17 | **SOS sheet waits up to ~15 s for GPS and address before showing any call button** (F5) | A second per second when water is rising | Task H2 (ready) |
| 18 | **Home level can come from a sensor anywhere in Bangkok**, under a header saying "your last known area" (F10) | Can show Danger on a dry street or Safe at a flooded door | Decision 9, then H3 |
| 19 | **Reports look sent but stay on the phone; no "trapped / need medicine" category** (F4) | People may believe help was told | H4a ready (notice); H4b needs category wording from you |
| 20 | **SOS sheet: 1669 is the big red button, 1784 is small; SMS has no recipient** (F5) | A flood-stranded family wants the disaster line | Decision 10, then H5 |
| 21 | **Danger advice "Leave for a shelter now" is an order, wrong for 25th floor or wheelchair** (F11) | Conflicts with hard rule 2 | Decision 11 (your wording) |
| 22 | **Shelter details: open/full, pets, ramp, phone** (F6; 19 of 111 have a phone, none have capacity or status) | Walking through water to a closed or full gate | Data source (Decision 12), then H7 |
| 23 | **Guide for a week indoors** (condo lifts and pumps, 7-day supplies, pets, infants, people who cannot move) (F7) | The audit's 100 people mostly stay home | Your text and expert sign-off (Decision 13), then H8 |
| 24 | **Family "I am OK" message and a 7-day checklist** (F12) | Seven days is long; battery is short | Decision 14, then H9 |

## 1.5 APIs and data sources needed

Status key: **Done**, **Planned** (a task below), **Blocked** (needs permission or key). Section numbers refer to `docs/DEVELOPMENT_PLAN.md` §3.

| Source or API | Used for | Status | Notes |
|---|---|---|---|
| Own backend `POST /ingest`, `GET /snapshot`, `GET /health` | Community water sensors | **Done** | HMAC per device, plain HTTP; needs a TLS proxy |
| Own backend `GET /flood-recurrence` + GISTDA gateway (§3.1 row 106) | "Flooded here before" card | **Done**, uncommitted | GISTDA key, server-side; licence "Open Data Common"; label must say "no record is not a safety statement" |
| TMD CAP feed `https://www.tmd.go.th/en/api/xml/CAP` (§3.1 row 91) | Official storm and heavy-rain alerts | **Done** (Phase A, tests pass; live feed run still to do by you) | Only source with an explicit reuse statement ("public domain"); credit TMD. Thai feed `…/api/xml/CAP` not yet fetched |
| Own backend `GET /alerts` | Serves the normalised TMD snapshot to the phone | **Done** (Task 4) | New route in the same process |
| Nominatim reverse geocode (`place_lookup.dart`) | Address in words | **Done, needs a decision** | The phone sends GPS to a third party (OSM). Conflicts with "coordinates never leave the phone" and OSM's usage policy (identify the app, low volume). Decide: self-host, proxy through the backend, or accept and disclose in the privacy notice |
| Google Maps link (`emergency_launcher.dart`, SOS share text) | Directions, shared location link | **Done** | User-initiated only |
| HII/thaiwater, RID telemetry (§3.1 rows 99, 103) | River levels | Blocked | No licence shown; ask in writing |
| FCM / APNs | Push | Blocked | Owner said "later"; needs Firebase project and packages |
| COD-AB boundaries, CC BY-IGO (§5.2) | Province/district targeting | Planned (B1) | Large files; simplify before bundling; fix TH1008 Thai name |
| T-Alert / Cell Broadcast | Official life-safety channel | **Not an API** | The app cannot send or read it. Point to it in the disclaimer (already) |

## 1.6 Decisions only you can make

Already answered: D1 backend (yes, hosting open), D2 push (yes in principle, Firebase "later"), D12 crash reports (opt-in only). Open, in order of what they unblock:

1. **Confirm the severity → tier mapping** in `docs/INPUTS_NEEDED.md` §1 (proposal: Minor→Watch, Moderate→Warning, Severe→Warning, Extreme→Danger, missing→Watch). Unblocks Task 2.
2. **Backend host, budget, who deploys** (D1). Unblocks any real use.
3. **App name, publisher, contact email, data controller** (D13). Unblocks privacy notice and store.
4. **Thai wording** for the four advice lines and the disclaimer (INPUTS_NEEDED §4).
5. **Nominatim question** above.
6. **Pilot area and size** (OWNER_TODO §2).
7. **Edit PRODUCT.md** (list in 1.4 item 15).
8. **Which agencies to send permission letters to** (INPUTS_NEEDED §7). I draft; you send.

From the 2026-11-19 persona audit (each unblocks one Phase H task):

9. **Home level per area (F10):** (a) label the sensor level as "nearest community sensor: name, distance" and stop calling it "your area"; or (b) show sensors only within a radius you choose; or (c) keep as is. Touches D15. Unblocks H3.
10. **SOS sheet order and family numbers (F5):** which is the big button (1669, 1784, or two side by side), and may the phone store up to 3 family numbers for the SMS recipient. Unblocks H5.
11. **Danger advice line (F11):** you rewrite it, or tell me to leave it. I will not reword it. Unblocks nothing in code, but it is a hard-rule-2 conflict.
12. **Shelter status data (F6):** where does open/full/pets/ramp come from (BMA, district offices, a phone call list)? Unblocks H7.
13. **Guide for a week indoors (F7):** you and the two expert reviewers write it (Thai first). Unblocks H8.
14. **Family check-in and 7-day checklist (F12):** do you want them, and which messenger (plain SMS only, because no new packages)? Unblocks H9.
15. **Location at app open (H1):** approve asking permission on first launch with a plain reason, and approve the permission-reason wording (I write a DRAFT, you rewrite). The Nominatim question (5) still applies.

---

# Part 2 — Build plan

## File structure (Phase A)

| File | Responsibility |
|---|---|
| `backend/tmd_cap.py` (new) | Pure functions: feed links, parse one CAP file, build a snapshot. No network inside the parsers |
| `backend/tmd_poller.py` (new) | `Poller`: fetch feed + files, keep last good snapshot, thread loop |
| `backend/capture_cap.py` (new) | One-off CLI that saves real CAP files as test fixtures |
| `backend/fixtures/cap/` (new) | Real TMD files (Actual, Update/Cancel, Test if seen, Thai) |
| `backend/test_tmd_cap.py`, `backend/test_tmd_poller.py` (new) | Tests |
| `backend/sensor_ingest.py` | Add `GET /alerts`, start the poller when `--tmd-feed` is given |
| `lib/services/alert_service.dart` | Age from `generatedAt` |
| `lib/main.dart` | Pass `ALERT_SNAPSHOT_URL` |
| `test/alert_service_test.dart`, `test/widget_test.dart` | Freshness and Home tests |
| `.github/workflows/ci.yml` | Run all backend tests |

**Snapshot contract** (backend produces, `OfficialAlert.fromJson` reads, already in `lib/models/official_alert.dart`):

```json
{"generatedAt": "2026-11-18T03:00:00Z",
 "alerts": [{"id": "TMD20261112062845_2", "sender": "TMD", "status": "Actual",
   "msgType": "Alert", "level": "warning",
   "headline": {"en": "Heavy Rain…", "th": "…"},
   "sent": "2026-11-11T23:28:45Z", "expires": "2026-11-12T11:28:45Z",
   "references": [], "polygons": [[[100.5, 13.7], [100.6, 13.7], [100.6, 13.8]]]}]}
```

`level` is one of `safe|watch|warning|danger`. `polygons` rings are `[lon, lat]`.

---

### Task 0: Land the in-progress GISTDA flood-history work

**Files:**
- Modify: `.gitignore` (add `sensors.db`, `backend/sensors.db`)
- Review and commit: the uncommitted files listed in Part 1 §1.3
- Test: existing suites

**Interfaces:** none.

- [x] **Step 1: Run `flutter analyze`, `flutter test`, `cd backend && python -m unittest discover`.** Expected: all pass (analyze clean; the Flutter run includes `design_test.dart`).
- [x] **Step 2: Review the 8 modified golden PNGs with the owner** (open them; they were redrawn by the Home/About/Map edits). Keep them only if the owner agrees; otherwise revert the UI edit that changed them.
- [x] **Step 3: Add `sensors.db` and `backend/sensors.db` to `.gitignore`.**
- [x] **Step 4: Commit in two commits** (flood-history feature; UI polish and goldens). Do not push.

### Task 1: TMD CAP feed reader and real fixtures

**Files:**
- Create: `backend/tmd_cap.py`, `backend/capture_cap.py`, `backend/test_tmd_cap.py`, `backend/fixtures/cap/*.xml`
- Create: `docs/CAP_FIELDS.md` (field report)

**Interfaces:**
- Produces: `feed_links(rss_xml: str) -> list[str]` (the CAP file URLs, in feed order, de-duplicated).

- [x] **Step 1: Write the failing test** in `backend/test_tmd_cap.py`: `test_feed_links_returns_cap_urls_in_order` feeds a small RSS string with 3 `<item><link>` entries (one duplicate) and asserts the 2 distinct URLs in order; `test_feed_links_ignores_garbage` asserts `feed_links("not xml") == []`.
- [x] **Step 2: Run** `cd backend && python -m unittest test_tmd_cap -v`. Expected: FAIL (module missing).
- [x] **Step 3: Implement `feed_links` in `backend/tmd_cap.py`** with `xml.etree.ElementTree`; bad XML returns `[]`.
- [x] **Step 4: Run the tests.** Expected: PASS.
- [x] **Step 5: Write `backend/capture_cap.py`** (`python capture_cap.py <feed_url> <out_dir>`): downloads the feed and each linked file with `urllib`, writes `<out_dir>/<name>.xml`. Run it against the English feed (and the Thai feed if it answers) over several days; keep every distinct kind of file seen (Actual, Update, Cancel, Test, Thai-only, no `expires`, no polygon). Commit the fixtures.
- [x] **Step 6: Write `docs/CAP_FIELDS.md`:** a table of which fields TMD actually fills across the fixtures (this closes the `[unverified]` in DEVELOPMENT_PLAN §7.2), and how Thai files relate to English ones (same identifier? suffix?).
- [x] **Step 7: Commit** `feat(backend): TMD CAP feed reader and real fixtures`.

### Task 2: Parse one CAP file into a snapshot alert

**Files:**
- Modify: `backend/tmd_cap.py`
- Test: `backend/test_tmd_cap.py`

**Interfaces:**
- Consumes: fixtures from Task 1.
- Produces: `SEVERITY_TO_LEVEL: dict[str, str]` (owner-confirmed mapping, default `watch` for missing/unknown); `parse_cap(xml_text: str) -> dict | None` returning one alert in the snapshot shape (`None` for unparseable input); `base_id(identifier: str) -> str` (strips a trailing `-en`/`-th` language suffix).

- [x] **Step 1: Write the failing tests** (use the real fixtures; the assertions below name the behaviour, fill exact values from the fixture):
  - `test_polygon_axis_order`: a CAP polygon `"13.7,100.5 13.7,100.6 13.8,100.6"` becomes ring `[[100.5,13.7],[100.6,13.7],[100.6,13.8]]` (lon first).
  - `test_times_are_utc`: `sent` `2026-11-12T06:28:45+07:00` → `2026-11-11T23:28:45Z`.
  - `test_missing_expires_is_null`: no `<expires>` → `"expires": None` (the app applies its 6 h default and labels it).
  - `test_severity_mapping`: Minor→watch, Moderate→warning, Severe→warning, Extreme→danger, missing→watch.
  - `test_references_become_plain_ids`: `<references>TMD,TMD2026X_1-en,2026-11-12T06:00:00+07:00</references>` → `["TMD2026X_1"]`.
  - `test_status_and_msgtype_pass_through`: `Test` and `Cancel` are kept (the app filters; debug view needs them).
  - `test_headline_keyed_by_language`: `en-US` info → `headline == {"en": "<text>"}`.
  - `test_no_polygon_alert_is_kept`: an alert with only `geocode` returns a dict with `polygons == []`.
  - `test_garbage_returns_none`.
- [x] **Step 2: Run** `python -m unittest test_tmd_cap -v`. Expected: FAIL.
- [x] **Step 3: Implement `parse_cap`, `base_id`, `SEVERITY_TO_LEVEL`** in `backend/tmd_cap.py`. Namespace `urn:oasis:names:tc:emergency:cap:1.2`. Take the highest-severity `<info>` for `level`; collect polygons from all `<area>` elements.
- [x] **Step 4: Run the tests.** Expected: PASS.
- [x] **Step 5: Commit** `feat(backend): parse TMD CAP alerts into the snapshot shape`.

### Task 3: Snapshot builder and poller that keeps the last good data

**Files:**
- Modify: `backend/tmd_cap.py`
- Create: `backend/tmd_poller.py`, `backend/test_tmd_poller.py`

**Interfaces:**
- Consumes: `feed_links`, `parse_cap`, `base_id` (Tasks 1–2).
- Produces:
  - `merge_languages(alerts: list[dict]) -> list[dict]` (merges English and Thai files of one alert by `base_id`; `headline` gets both languages).
  - `build_snapshot(alerts: list[dict], now: datetime) -> dict` (adds `generatedAt`; drops alerts expired more than 24 h ago; keeps alerts with no expiry for 24 h after `sent`).
  - `class Poller` with `__init__(self, feed_urls: list[str], get: Callable[[str], str], clock: Callable[[], datetime])`, `poll_once(self) -> None`, `snapshot_json(self) -> str`, `run_forever(self, every_s: int = 120) -> None`.

- [x] **Step 1: Write the failing tests** in `test_tmd_poller.py` with a fake `get` and a fake clock:
  - `test_poll_builds_snapshot_from_feed_and_files`.
  - `test_one_bad_file_is_skipped`: a feed of 3 links where one returns garbage and one raises → the third alert is still served.
  - `test_feed_down_keeps_last_good_and_old_generated_at`: second `poll_once` fails entirely → `snapshot_json()` still has the first alerts and the **first** `generatedAt` (age keeps growing).
  - `test_first_poll_failure_serves_empty_with_no_generated_at`: nothing ever fetched → `{"alerts": []}` with no `generatedAt` key (`/alerts` answers 503 for it; the app also rejects a live body without `generatedAt`).
  - `test_oversize_file_skipped`: a body over 256 KB is skipped.
  - `test_no_polygon_alert_counted`: snapshot has `"noPolygon": <count>` for alerts with empty polygons (so a missing area match is visible, not silent).
  - `test_languages_merged`.
- [x] **Step 2: Run** `python -m unittest test_tmd_poller -v`. Expected: FAIL.
- [x] **Step 3: Implement** in `tmd_cap.py` (`merge_languages`, `build_snapshot`) and `tmd_poller.py` (`Poller`). A failed feed fetch changes nothing. A per-file failure is caught and skipped. Use a lock around the stored snapshot string.
- [x] **Step 4: Run the tests.** Expected: PASS.
- [x] **Step 5: Commit** `feat(backend): TMD poller that serves last good alerts`.

### Task 4: Serve `GET /alerts` and run the poller

**Files:**
- Modify: `backend/sensor_ingest.py` (handler near `do_GET`, `main()` flags), `backend/test_ingest.py`
- Modify: `.github/workflows/ci.yml` (backend job runs `python -m unittest discover`)
- Modify: `README.md` (flags)

**Interfaces:**
- Consumes: `Poller.snapshot_json()`, `Poller.run_forever()`.
- Produces: `GET /alerts` → `200` JSON snapshot (`Content-Type: application/json`); `404` when no poller is configured. New flag `--tmd-feed <url>` (repeatable, e.g. English and Thai feeds) that starts a daemon thread running `Poller.run_forever`.

- [x] **Step 1: Write the failing tests** in `test_ingest.py`: `test_alerts_route_serves_poller_snapshot` (handler built with a stub poller returns its JSON); `test_alerts_route_404_without_poller`.
- [x] **Step 2: Run** `python -m unittest test_ingest -v`. Expected: FAIL.
- [x] **Step 3: Add the route** by passing an optional `poller` into `make_handler`; add `--tmd-feed` to `main()`.
- [x] **Step 4: Run** `python -m unittest discover`. Expected: PASS (all backend tests).
- [x] **Step 5: Change the CI backend step** to `python -m unittest discover` (it currently runs only `test_ingest`, so `test_gistda` and the new tests never run in CI). Add `--tmd-feed` usage to the README.
- [x] **Step 6: Commit** `feat(backend): GET /alerts and TMD polling flag`.

### Task 5: App reads alerts and ages them from the snapshot time

**Files:**
- Modify: `lib/services/alert_service.dart` (`_apply`, `isStale`, `fetchedAt`), `lib/main.dart:127`
- Test: `test/alert_service_test.dart`, `test/widget_test.dart`

**Interfaces:**
- Consumes: the snapshot contract above.
- Produces: `AlertService.fetchedAt` now returns the **data time** (`generatedAt` when present, otherwise the download time). `AlertService.isStale` is computed from it. Build flag `ALERT_SNAPSHOT_URL`.

- [x] **Step 1: Write the failing tests** in `test/alert_service_test.dart`:
  - `stale_when_snapshot_generated_long_ago_even_if_just_downloaded`: fetcher returns JSON with `generatedAt` 2 h before the injected clock → `hasSnapshot` true, `isStale` true.
  - `fresh_when_generated_recently`.
  - `snapshot_without_generated_at_uses_download_time` (keeps current behaviour for old caches).
- [x] **Step 2: Write the failing widget test** in `test/widget_test.dart` (follow the existing "Home shows no invented warning when no alert data exists" test and `test_helpers.dart`): with a fixture snapshot containing a `warning` alert whose polygon contains the test location, Home shows the Warning tier word and the issuer "TMD"; with the location outside the polygon, Home does **not** show Warning.
- [x] **Step 3: Run** `flutter test test/alert_service_test.dart test/widget_test.dart`. Expected: FAIL.
- [x] **Step 4: Implement:** in `_apply`, read `generatedAt` if present and store it as the data time; `main.dart` passes `snapshotUrl: const String.fromEnvironment('ALERT_SNAPSHOT_URL')` to `AlertService`.
- [x] **Step 5: Run** `flutter analyze && flutter test $(ls test/*_test.dart | grep -v design_test)`. Expected: clean, all pass. Then run `flutter test test/design_test.dart` locally and review any golden diffs with the owner.
- [x] **Step 6: Manual check:** run the backend with `--tmd-feed https://www.tmd.go.th/en/api/xml/CAP`, then `flutter run --dart-define=ALERT_SNAPSHOT_URL=https://<host>/alerts` (HTTPS is required by the app; use a local TLS proxy). Expected: alert list matches the TMD feed; stop the backend → after 30 min the app shows the stale banner.
- [x] **Step 7: Commit** `feat(app): age official alerts from the snapshot time and wire ALERT_SNAPSHOT_URL`.

**Phase A done when:** real TMD alerts appear for a phone inside their area, expired and cancelled ones vanish, a dead poller shows stale, tests green.

---

## Phase B: province targeting and alert screens (Tasks 6–11)

Owner go-ahead 2026-11-18 ("develop the app in phase B"); owner chose "assistant downloads COD-AB". Scope decision: **provinces only** (TMD sends only ISO 3166-2 province codes `TH-NN`, 4 to 9 per file; no district codes seen), so districts, tambons and the TH1008 district-name fix are deferred. COD-AB source: HDX dataset `cod-ab-tha`, resource `tha_admin_boundaries.shp.zip`, layers `tha_admin1` (provinces) and `tha_admin2` (districts, used only to test the bundle). A copy is already downloaded outside the repo (temporary, may vanish; re-fetch from HDX if so): `C:\Users\Admin\AppData\Local\Temp\claude\5c23be1f090ea38f\f961e356-9c26-4f82-b2e1-bd31e2ce112e\scratchpad\codab\tha_admin1.shp` (+ `.dbf`, `.prj`; WGS84 degrees; 77 features; fields `adm1_pcode` like `TH10`, `adm1_name` English, `adm1_name1` Thai, UTF-8). `TH-NN` ↔ `THNN` by dropping the hyphen; Task 6 must verify every code TMD uses exists in the bundle.

**Rulings for Phase B (controller; reversible):**
- PROVISIONAL, decided in Task 8 step 1 from data: an alert with polygons is matched by polygons only, province codes only when it has no polygons. Real TMD files have both polygons and province codes; \"geocode only\" has only been seen in the synthetic fixture, so Phase B's real gains are the area tag, detail screen and history. If any real fixture lists provinces its polygon does not cover, the owner chooses polygon-only or polygon-or-province.\n- Model routing: Tasks 7 and 8 (safety-critical) are implemented by Opus and reviewed by Sonnet; Tasks 6, 9, 10, 11 by Sonnet; Haiku for lookups; final whole-branch review by Opus.
- Province matching only escalates a level. Unknown province (no GPS, at sea, bundle failed to load) never lowers anything and never creates Safe; such alerts are still listed.
- All new user-facing wording is `DRAFT` for the owner to rewrite (Thai first). No wording of Guide, first aid or the disclaimer is touched.

### Task 6: Province boundary bundle (build tool and asset)

**Files:**
- Create: `backend/build_provinces.py` (stdlib only: reads `.shp`/`.dbf` with `struct`, simplifies with Douglas-Peucker, writes JSON; under `backend/` so CI's `unittest discover` runs its test), `backend/test_build_provinces.py`, `assets/boundaries/th_provinces.json`
- Modify: `pubspec.yaml` (add `assets/boundaries/` to `flutter: assets:`; no new package)

**Interfaces:**
- Produces: `th_provinces.json` = `{"source": "...CC BY-IGO...", "provinces": [{"code": "TH-10", "nameTh": "...", "nameEn": "...", "rings": [[[lon, lat], ...], ...]}]}`. `code` uses the `TH-NN` form. All rings of a province are in one flat list; holes are plain extra rings (even-odd fill). Coordinates rounded to 4 decimals.
- Simplification must keep **shared borders identical**: simplify each shared border once (or snap vertices) so neighbouring provinces leave no gap or overlap. Size is secondary: target ≤ 600 KB, but lower the tolerance rather than accept misses.

- [ ] **Step 1: Write failing tests** in `backend/test_build_provinces.py`: `douglas_peucker` keeps endpoints and drops a collinear point; `read_dbf` returns Thai text intact from a tiny synthetic DBF; `province_code('TH10') == 'TH-10'`; a built-in sample ring round-trips.
- [ ] **Step 2: Run** `cd backend && python -m unittest test_build_provinces`. Expected: FAIL.
- [ ] **Step 3: Implement** the tool and run it on the downloaded COD-AB folder.
- [ ] **Step 4: Verify the output** with a test or a checked command: 77 provinces; every code matches `^TH-\d{2}$`; every `TH-NN` code appearing in `backend/fixtures/cap/*.xml` geocodes exists; Bangkok (13.7563, 100.5018) lies in `TH-10`; Phuket (7.89, 98.39) lies in `TH-83`; **all 928 `tha_admin2` district centres (`center_lat`, `center_lon`) resolve to their parent province (`adm1_pcode`) in the simplified bundle and to exactly one province** (a one-off check script, result recorded in the report; a handful of centres that fall outside their own district in the source are listed, not hidden); file size ≤ 600 KB.
- [ ] **Step 5: Commit** `feat(data): simplified province boundaries from COD-AB (CC BY-IGO)`.

### Task 7: Backend carries province codes in the snapshot (hard: Opus implements)

**Files:**
- Modify: `backend/tmd_cap.py` (`_parse_cap`, `merge_languages`, `build_snapshot`)
- Test: `backend/test_tmd_cap.py`, `backend/test_tmd_poller.py`; regenerate `test/fixtures/alerts_snapshot.json` (`cd backend && UPDATE_CONTRACT=1 python -m unittest test_tmd_poller`)

**Interfaces:**
- Produces: each snapshot alert gains `areaCodes: ["TH-80", ...]` (sorted, deduplicated, only values matching `^TH-\d{2}$` from `<geocode>` whose `valueName` is `ISO3166-2`; anything else skipped, never raising). `merge_languages` unions codes. The snapshot also gains `noArea`: count of kept alerts with neither polygons nor `areaCodes`.
- Consumes: Task 2/3 behaviour unchanged (cancel handling, pruning, skippedFiles).

- [x] **Step 1: Failing tests:** the real fixtures give the expected code sets (e.g. a file with TH-80, 84, 90–96); `synthetic_geocode_only.xml` gives codes and no polygons; an invalid code (`TH-9`, `XX-10`, wrong `valueName`) is dropped; English+Thai twins merge to one union; `noArea` counts only area-less alerts; old snapshots without `areaCodes` still parse in the app (Task 8).
- [x] **Step 2: Run** `cd backend && python -m unittest discover`. Expected: FAIL.
- [x] **Step 3: Implement** in the three functions above.
- [x] **Step 4: Regenerate the contract file** and run all backend tests. Expected: PASS.
- [x] **Step 5: Commit** `feat(backend): carry province codes in the alert snapshot`.

### Task 8: App model, province locator and matching rule (safety-critical: Opus reviews)

**Files:**
- Modify: `lib/models/official_alert.dart` (`areaCodes`), `lib/services/alert_rules.dart` (`levelAt`), `lib/services/alert_service.dart` (`levelAt` passes the province)
- Create: `lib/services/province_locator.dart` (`ProvinceBoundaries`: loads the asset; `Province{code,nameTh,nameEn,rings}`; `String? codeAt(LatLng)`; `Province? byCode(String)`), `test/province_locator_test.dart`
- Test: `test/alert_rules_test.dart`, `test/alert_service_test.dart`, `test/alert_contract_test.dart`

**Interfaces:**
- Consumes: Task 6 asset, Task 7 snapshot (`areaCodes`, absent in old caches → empty).
- Produces: `OfficialAlert.areaCodes: List<String>`; **one matching function** `AlertRules.matches(OfficialAlert a, LatLng point, String? provinceCode) -> bool` used by both `levelAt` and Task 9's area tag: it matches when the alert has polygons and one contains the point, **or** it has no polygons and `provinceCode != null` and `areaCodes` contains it (provisional rule, see Step 1). `AlertRules.levelAt(alerts, point, now, {String? provinceCode})` calls `matches`. `ProvinceBoundaries.parse(String json)` (pure, for tests) and `ProvinceBoundaries.load()` (asset). Point-in-province uses `AlertRules.contains` over all rings with even-odd (hole = outside).

- [x] **Step 1: Data check first (decides the rule):** for every real fixture in `backend/fixtures/cap/`, test whether the polygon(s) cover each listed province (using the Task 6 bundle). Record the result in `docs/CAP_FIELDS.md`. If a listed province is not covered by the polygons, stop and report to the controller: the owner picks polygon-only or polygon-or-province. Do not guess.\n- [x] **Step 1b: Failing tests:** codeAt for Bangkok, Phuket, a point in the Gulf (null), a point on the 102°E line inside Nakhon Ratchasima; a province with a hole (synthetic) excludes the hole; `levelAt` escalates for a geocode-only alert when `provinceCode` matches, not when it differs, not when `provinceCode` is null; an alert **with** polygons ignores `areaCodes`; old JSON without `areaCodes` parses; contract test reads `areaCodes` from the regenerated fixture.
- [x] **Step 2: Run** the listed test files. Expected: FAIL.
- [x] **Step 3: Implement** as specified. A bundle that fails to load must leave `codeAt` returning null (never throw into the UI).
- [x] **Step 4: Run** `flutter analyze` and the CI test set. Expected: clean, PASS.
- [x] **Step 5: Commit** `feat(app): match province-only alerts to the user's province`.

### Task 9: Home uses the province and labels each notice's area

**Files:**
- Modify: `lib/main.dart` (create and pass `ProvinceBoundaries`), `lib/screens/home_screen.dart` (`homeLevel`, `_OfficialAlerts`), `lib/services/alert_service.dart` (accepts the locator if needed)
- Test: `test/widget_test.dart`, `test/home_alerts_test.dart` (new, if clearer)

**Interfaces:**
- Consumes: Task 8 (`ProvinceBoundaries.codeAt`, `AlertRules.levelAt(..., provinceCode:)`), `OfficialAlert.areaCodes`.
- Produces: each notice row shows an area tag with icon **and** word: "In your area" / "Other areas" / "Area unknown" (DRAFT wording, Thai first, via `context.tr`). Notices in your area sort first; nothing is hidden. Home's level uses the province of the stored location. The tag comes from `AlertRules.matches`, the same function that drives the level, so tag and level cannot disagree. The locator is optional (nullable) so existing widget tests keep working; the bundle loads lazily and never delays the map startup gate. Tests inject a small `ProvinceBoundaries.parse(...)` fixture, not the asset.

- [x] **Step 1: Failing widget tests** (Thai default, also 1.5× text scale): a Warning geocode-only alert for the test location's province → Home shows Warning and the tag "In your area"; same alert for another province → Home level not Warning and tag "Other areas"; no location set → tag "Area unknown" and level unchanged.
- [x] **Step 2: Run** `flutter test test/widget_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement.** Mark all new strings `// DRAFT` for the owner.
- [x] **Step 4: Run** `flutter analyze` and the CI test set. Expected: clean, PASS.
- [x] **Step 5: Commit** `feat(app): province-aware notices on Home`.

### Task 10: Alert detail screen

**Files:**
- Create: `lib/screens/alert_detail_screen.dart`, `test/alert_detail_test.dart`
- Modify: `lib/screens/home_screen.dart` (rows open the detail)

**Interfaces:**
- Consumes: `OfficialAlert`, `ProvinceBoundaries.byCode`, `AlertService.fetchedAt`.
- Produces: `AlertDetailScreen(alert, alerts, provinces)` showing: level pill (icon+word+colour), full headline in the current language with the other language below, issuer (`sender`), issued time, received/updated time (the snapshot's data time), expiry or the label "no expiry given (shown for 6 hours)", and the affected provinces by Thai and English name (from `areaCodes`; if only polygons, "Area shown on the map"). Footer line: official source, not this app (DRAFT wording).

- [x] **Step 1: Failing widget tests:** an alert with expiry shows it; without expiry shows the "no expiry given" label; province names appear for known codes and an unknown code shows the raw code; text at 1.5× does not overflow; tap targets ≥ 48 dp.
- [x] **Step 2: Run** `flutter test test/alert_detail_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement**, all strings via `context.tr`, marked `// DRAFT`.
- [x] **Step 4: Run** analyze and the CI test set. Expected: clean, PASS.
- [x] **Step 5: Commit** `feat(app): alert detail screen`.

### Task 11: Alert history

**Files:**
- Modify: `lib/services/storage_service.dart` (`alertHistory`, `saveAlertHistory`, key `alert_history`), `lib/services/alert_service.dart` (records ended alerts)
- Create: `lib/screens/alert_history_screen.dart`, `test/alert_history_test.dart`
- Modify: `lib/screens/home_screen.dart` (a "History" entry under Official notices)

**Interfaces:**
- Consumes: `OfficialAlert`, `AlertRules.visible`.
- Produces: `AlertService.history` (newest first, at most 50, entries older than 30 days dropped): every alert that was visible at some refresh and later is not (expired, cancelled or replaced), stored as a compact record (id, level, headlines, sender, sent, expires, `areaCodes`; **no polygons**, to keep storage small) with an `endedAt` time and a reason word "Expired" / "Cancelled" / "Replaced". The ids visible at the last refresh are persisted, so \"was visible, now is not\" survives a restart. History never feeds `levelAt`, `visibleAlerts` or Home's level. Offline use works from storage.

- [x] **Step 1: Failing tests:** an alert visible at refresh 1 and cancelled at refresh 2 appears in history as "Cancelled"; expired alert appears as "Expired"; history is capped at 50 and pruned at 30 days; history survives a restart (storage round-trip); history alerts never appear in `visibleAlerts`; a stale or empty snapshot does not add history entries by itself.
- [x] **Step 2: Run** `flutter test test/alert_history_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement** history recording inside `_apply`, plus the screen (rows reuse the detail screen from Task 10).
- [x] **Step 4: Run** analyze and the CI test set. Expected: clean, PASS.
- [x] **Step 5: Commit** `feat(app): alert history`.

**Phase B done when:** a province-only TMD alert raises the level for people inside that province and not elsewhere; each notice says whether it is in your area; a notice opens to a detail screen; ended alerts appear in history; analyze and tests green.

---

## Phase H: panic-readiness (from the 2026-11-19 persona audit; Tasks H0–H9)

Source: [`docs/audits/2026-11-19-bangkok-flood-persona-audit.md`](../../audits/2026-11-19-bangkok-flood-persona-audit.md). Finding ids F1–F14 below are that report's. The report is simulated personas reasoning from code and two golden images, not user research, so every task here fixes something that was **verified in code**, and none rests on a persona's opinion alone.

**Order of work:** Phase C (a deployed warning path) is the real blocker and is independent of Phase H. Inside Phase H the order is H2, H4a, H1, then the decision-gated tasks. Everything in Phase H keeps the Global Constraints: no new package, never a false Safe, every state icon + word + colour, all new wording `DRAFT` (Thai first) for the owner, Guide/first-aid/disclaimer text untouched.

**Routing (CLAUDE.md, "from Phase B on"):** H1 and H2 touch SOS and location, so Opus advises first, then Sonnet implements, then a fresh Sonnet reviewer; H4a, H3 Sonnet only; Haiku for lookups.

### Task H0: Real-person phone session (owner runs it; no code)

- [ ] Five people (include one over 65, one non-Thai reader, one condo resident) get a phone with a release build, no signal and no instructions, and the scenario "flood in 24 hours". Record: time to find SOS, time to find a shelter, what they think "Report" does. Compare with the audit's predictions (F1, F4, F5, F8). Output: a short note in `docs/audits/`. Needs: a build, five volunteers.

### Task H1: Ask for location when the app opens, and show how old it is (audit F1, F3)

**Needs first:** owner's yes in 1.6 item 15.

**Files:**
- Modify: `lib/services/storage_service.dart` (store `lastPositionAt`; old installs read as unknown age), `lib/services/location_service.dart` (a `refreshQuietly()` that never throws and never blocks the UI), `lib/screens/home_screen.dart` (header and shelter card use the age), `lib/main.dart` (call once after the map gate)
- Test: `test/location_service_test.dart`, `test/widget_test.dart`

**Interfaces:**
- Produces: `StorageService.lastPositionAt: DateTime?`; `LocationService.refreshQuietly()` asks for permission once with the OS prompt (DRAFT reason string in the platform manifests, owner approves), reads GPS with the existing 10 s limit, and on any failure leaves the old position untouched. Home eyebrow reads "Your last known area" plus the age ("updated 2 h ago", DRAFT), and when the position is older than 24 h it says so and still never changes a level.
- Does not change: coordinates stay on the phone; this task adds no network call (the Nominatim lookup is not triggered here).

- [ ] **Step 1: Failing tests:** `refreshQuietly` saves position and `lastPositionAt` on success; on denied/timeout/service-off it keeps the old position and its old time and does not throw; a position older than 24 h shows the "old position" wording on Home; first launch with permission granted shows the nearest shelter without SOS or Report being used; first launch with permission denied looks exactly like today (no error, no red).
- [ ] **Step 2: Run** `flutter test test/location_service_test.dart test/widget_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Mark new strings `// DRAFT`.
- [ ] **Step 4: Run** `flutter analyze` and the CI test set. Expected: clean, PASS.
- [ ] **Step 5: Commit** `feat(app): find the user's area at launch and show its age`.

### Task H2: The SOS sheet opens at once; the address fills in later (audit F5, first part)

**Files:**
- Modify: `lib/screens/home_screen.dart` (`_onSos`, `_SosSheet`), `lib/services/location_service.dart` only if a split is needed
- Test: `test/widget_test.dart` (or `test/sos_sheet_test.dart`)

**Interfaces:**
- Today `_onSos` awaits `getCurrent()` (up to 10 s) and `describe()` (up to 5 s) before `showModalBottomSheet`. New behaviour: open the sheet right after the hold completes with the call buttons enabled; the message block shows "Finding your location…" and updates when the position (fresh, else saved) arrives, and again when the address arrives; if neither arrives the existing "cannot find location, call an emergency number" banner shows. The call buttons never depend on GPS. Same wording as today for the message text; only new string is the waiting line (DRAFT).
- Does not change the SMS/share text format (it stays bilingual) or the order of the numbers (that is H5).

- [x] **Step 1: Failing widget tests** with a fetcher/location stub that never completes: after the hold, the sheet is present within one frame and the 1669 button is tappable; when the stub completes later the message appears; when it fails the banner appears and the call buttons are still there; closing the sheet while locating does not throw.
- [x] **Step 2: Run** the test file. Expected: FAIL.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** analyze and the CI test set. Expected: clean, PASS.
- [ ] **Step 5: Commit** `fix(app): open the SOS sheet at once, fill in the location when it arrives`. (Waits for the owner's yes.)

**Notes from H2 (not changed, owner to decide):** the SOS sheet's "cannot find location" and "GPS failed, saved position used" banners use `BannerKind.error` (red), which sits badly with "GPS failure is a normal state, never red". The Time line in the SOS message is now stamped when the position arrives, not when the sheet opens. `Semantics(liveRegion)` on the waiting row is untested on a real screen reader.

### Task H3: Home level that says where it came from (audit F10)

**Blocked by:** decision 9. Today `SensorService.level` is the worst station anywhere. Whatever option the owner picks, the Home card must stop implying that a distant sensor is "your area", must keep sensors from raising an area alert (D15), and must keep stale = no data. Written as exact tasks only after the choice. Test shape: two stations, one flooded far from the user's position, one dry near it.

### Task H4a: Say "not sent" before saving a report (audit F4, first part)

**Files:** `lib/screens/report_screen.dart`, `test/widget_test.dart`.

**Interfaces:** A persistent line above the Save button (icon + word, not a toast): "Saved on this phone only. No one is told." (DRAFT, Thai first), and the Save button label unchanged. The existing post-save toast stays. No new categories here.

- [x] **Step 1: Failing widget test:** the line is on screen before any save, at 1.5× text; present in Thai and English.
- [x] **Step 2: Run** `flutter test test/widget_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement.** Mark `// DRAFT`.
- [x] **Step 4: Run** analyze and the CI test set. Expected: clean, PASS.
- [ ] **Step 5: Commit** `fix(app): say before saving that a report is not sent`.

### Task H4c: "Get directions" opens the Google Maps app directly (owner request, 2026-11-19)

**Files:** `lib/services/emergency_launcher.dart`, `test/emergency_launcher_test.dart`. No new package.

**Interfaces:** `EmergencyLauncher.navigationUris(lat, lng, {required bool ios})` returns the links to try in order: Android `google.navigation:q=lat,lng`, iOS `comgooglemaps://?daddr=lat,lng&directionsmode=driving`, then the `https://www.google.com/maps/dir/?api=1&destination=lat,lng` link as the last fallback. `navigate` tries each until one opens. Only the shelter's coordinates go out, as today.
**Not done on purpose:** an embedded WebView of Google Maps (needs a new package, rule 8, and does not work offline) and an in-app route (needs a routing service). Both need the owner's explicit yes.

- [x] **Step 1: Failing test** for the link order on Android and iOS.
- [x] **Step 2: Run** `flutter test test/emergency_launcher_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** analyze and the CI test set. Expected: clean, PASS.
- [ ] **Step 5: Commit** `feat(app): open directions in the Google Maps app first`.

### Task H4b: Report categories for "trapped", "need medicine", "need evacuation" (audit F4, second part)

**Blocked by:** your wording for the new category names and a decision on whether the word "report" stays while nothing is sent (it may become "note for myself" until a rescue partner exists, item 14 of 1.4). Old reports keep working (categories are stored as keys).

### Task H5: SOS sheet order and family numbers (audit F5, second part)

**Blocked by:** decision 10. Without a new package the recipient is stored in `shared_preferences` as plain numbers; the SMS composer already takes a list (`EmergencyLauncher.sms(recipients, text)`). Test shape: no numbers saved → today's behaviour; numbers saved → composer gets them.

### Task H6: Review of the Danger advice line (audit F11)

**Blocked by:** decision 11 (owner wording). No agent edits it. Once the owner supplies text, the change is one string in `lib/l10n/l10n.dart` and its golden/test.

### Task H7: Shelter status, pets, ramp, phone (audit F6)

**Blocked by:** decision 12 (data source and permission). Needs a model change (`Shelter` gets optional `status`, `statusAt`, `petsOk`, `accessible`), shown with its confirmation date and never as "open" without a date. 12 of 50 districts are roughly 3 km or more from the nearest bundled shelter (rough centroid estimate in the report); more shelters are a data task, not code.

### Task H8: Guide for a week indoors (audit F7)

**Blocked by:** decision 13. Topics to be written by the owner and reviewed by the two experts: shelter-in-place in a condo (lifts, water pumps, electricity), 7-day water and food, pets, infants, people who cannot move, health after flood water. No agent writes this text. Earthquake and CPR topics stay as they are; whether to hide the earthquake topic for a flood-only release is also the owner's call.

### Task H9: Family check-in and 7-day checklist (audit F12)

**Blocked by:** decision 14. Plain SMS only (no new package). The check-in must say what it is and must never claim a rescuer received anything.

**Phase H done when:** a first-time user with permission granted sees their area and nearest shelter without pressing SOS; the SOS sheet shows call buttons immediately; the Report screen says before saving that nothing is sent; the Home level states where it came from; H0 has been run with five people and its note is filed.

---

## Phase R: visual redesign "Posted notice" (owner request 2026-11-21; Tasks R0–R9)

Source: [`docs/audits/2026-11-21-redesign-audit-and-direction.md`](../../audits/2026-11-21-redesign-audit-and-direction.md) (audit of 14 slop tells and the direction brief). **Status: PROPOSED. No code until the owner says yes.** Layout and styling only: no wording change, no new package, no font change (unless R-D2), no touch to `alert_rules`, `alert_service`, `sensor_service`, `backend/`, `firmware/`. Colour values and meanings of the four tiers stay. Verification for pure visual tasks: `flutter analyze` plus the screen's goldens at 1x and 1.5x text (review each PNG diff, never commit blindly); where logic is touched, TDD. Routing: R1 and R4 Opus advises, Sonnet implements; the rest Sonnet; a fresh reviewer per task; Opus for the final review.

### Task R0: Owner decisions (no code)

- [x] R-D1 16 sp minimum · R-D2 Sarabun only or a named extra face · R-D3 WATCH slab treatment · R-D4 two-line source line · R-D5 remove navy band and raised Call tab. **Answered 2026-11-21 (owner took the defaults): R-D1 yes, R-D2 Sarabun only, R-D3 yellow rule on a calm slab (loud stays warning+danger), R-D4 yes, R-D5 yes.**

### Task R1: Tokens and theme (Opus advises)

- [x] Neutral ground/rule colours in `app_palette.dart`; drop `cardShadow`; square/8 dp radii; the new type scale (nothing under 16 sp, weight-based hierarchy, tabular figures); update `AppTheme` and `test/design_test.dart` contrast pairs (both modes). Proof: analyze, `design_test` pairs pass.

### Task R2: Shared widgets

- [x] (R2: new widgets added in `lib/widgets/notice_ui.dart`, old ones removed in R10) Replace `SoftCard`/`SoftTile`/`BrandHeader`/`AccentRow`/`RoundChip`/`CollapsibleCard`/`StatusPill` with flat ruled equivalents (Section, Row, ScreenTitle, Tag); new vertical `LevelGauge` replaces `LevelMeter`; SOS bar without glow. Keep semantics labels and 48 dp targets.

### Task R3: Tab shell

- [x] (R3 done 2026-11-21; Thai tab labels wrap inside the word at 360 dp and 1.5x text: owner decision pending, shorter label or four tabs; design_test "Home: text contrast (English)" fails until R4) Five equal tabs with top-rule selection (no raised Call circle); rail variant matches. Goldens.

### Task R4: Home (Opus advises)

- [x] (R4 done 2026-11-21; short screens or text >= 1.3x fix SOS at the top, tall screens pin it; RuledRow drops its tap action from the screen-reader tree, R2 follow-up) Level slab (quiet and loud variants, no-data neutral), SOS bar, ruled sections for quick call, shelter, notices. Goldens: calm, danger, no-data, 360x640 at 1.5x, landscape, night.

### Tasks R5–R9: one screen each

- [x] R5 Call (done 2026-11-21) · [x] R6 Report (done 2026-11-21) · [x] R7 Guide and topic pages (done 2026-11-21; groups now always open, no fold) · [x] R8 Map and sheet (done 2026-11-21; ScreenTitle, flat banner, square sheet, two text tabs, ruled shelter rows, flat markers; test/map_screen_test.dart) · [x] R9 Settings, About, alert detail, alert history, flood history card, sensor readings (done 2026-11-21; pushed pages keep a ground AppBar for back, About's long title moved into the body so it wraps). Each: read the screen, apply the brief, analyze, goldens 1x and 1.5x, critique pass against the brief.

### Task R10: Whole-branch review and docs

- [x] (R10 done 2026-11-21: Opus review run, its must/should-fix items fixed except R-F1, DESIGN.md rewritten; owner decisions and device checks still open, see the final report) Opus reviews the whole phase against the brief and the hard rules; update `DESIGN.md` to the shipped system (not `PRODUCT.md`); full proof: `flutter analyze`, CI test set, goldens reviewed; report slop tells removed.

### Phase R findings outside the phase (2026-11-21, need the owner's yes before code)

- **R-F1 FIXED (2026-11-22; safety, hard rule 1):** `lib/widgets/sensor_readings.dart` (map sheet, Sensors tab): when the snapshot is stale, a station whose last band was Safe still shows a filled green SAFE tag under the "may be out of date" banner, while `SensorService.level` already turns stale Safe into null. Fix: show the neutral no-data tag when `sensors.isStale` and the band is safe; add a test. Likely predates Phase R. Fixed in `sensor_readings.dart` (stale Safe shows the neutral dash tag; the list redraws on the poll beat so a fresh tag ages out by itself); tests in `test/sensor_stale_safe_test.dart`.
- **R-F2:** `lib/services/emergency_launcher.dart` (Google Maps app first) and `test/emergency_launcher_test.dart` were already uncommitted before Phase R and are not part of it (see H4c).
- **R-F3 FIXED (2026-11-22; safety, hard rule 1, owner approved):** `SensorService` now checks staleness on its own 30 s poll tick (before and independent of the fetch, so a hung fetch cannot block it) and after a failed poll, and notifies once when staleness flips; recovery is one notify. The R-F1 timer in `_LiveStationsState` is removed (the list rebuilds from the service). Tests: `test/sensor_service_stale_test.dart`. Original finding:  `SensorService` (`lib/services/sensor_service.dart` ~line 105) keeps the old snapshot on a failed poll and does not call `notifyListeners()`, and nothing notifies when time alone makes the data stale. Home's level slab and `_LiveStations` listen only to it, so a phone that goes offline right after a Safe reading may keep showing Safe until the next successful poll. R-F1 added a timer inside the station list only. Probable fix: notify (or re-evaluate `isStale`) on a timer in the service or in Home; verify first by a test that goes offline after a Safe reading and advances the clock past the stale limit. Home's "(may be out of date)" line has the same exposure.
- **R-F4 (FIXED 2026-11-22, owner approved; `AlertService` ticks call `_notifyIfTimeChanged` and notify only when stale/visible set changes; tests in `test/alert_service_time_test.dart`; originally found 2026-11-22):** `AlertService` has the same no-notify-on-time gap. `isStale` (30 min) and expiry (via `visibleAlerts`/`levelAt`) change with the clock, but only `_apply` notifies. An expired official Danger stays on Home while offline, and the alert card's "may be out of date" notice never appears offline. Not a false Safe, because `combine` treats an official Safe as no information.
- **R-F5 (FIXED 2026-11-22; owner approved; one 15 s deadline over connect, headers and body in `httpGetText`, force-closes the client; `test/http_get_test.dart`):** `lib/services/http_get.dart` sets only `connectionTimeout`. A read that hangs after connecting leaves `_busy` true, so later `refresh()` calls return early and the service never recovers by itself.
- **R-F6 FIXED (2026-11-22; `clockBackSlack` 1 min in both services, tests in `sensor_service_stale_test.dart` and `alert_service_time_test.dart`) (safety, hard rule 1; Opus review 2026-11-22; needs the owner's yes):** if the phone clock moves BACKWARDS after a download (network time correction after boot, user changes it), the age is negative, so `isStale` stays false and old Safe sensor data stays Safe (`sensor_service.dart` ~63-64; same in `alert_service.dart` ~66-69). Fix: count a negative age beyond about 1 minute as stale; for sensors measure age with a `Stopwatch` (only counts forward). Test: download Safe, move the clock back 1 h, `level` must be null.
- **R-F7 FIXED (2026-11-22, owner approved; `AlertService._dataTime` no longer clamps a future `generatedAt`; `isStale` from R-F6 treats it as stale beyond the 1 min slack; tests in `alert_service_test.dart`, `alert_service_time_test.dart`):** `alert_service.dart` ~146 (older code): when the phone clock is behind, a cached snapshot's `generatedAt` is "in the future" and is clamped to now, so an old cache counts as fresh and the "may be out of date" notice is hidden. Not a false Safe (`combine` ignores an official Safe). Fix: treat a future `generatedAt` as stale.
- **R-F8 FIXED (2026-11-22, owner approved; `SensorService` only):** the app ages sensor data from its own download time (`sensor_service.dart` ~121) and ignores the `generatedAt` that `backend/sensor_ingest.py` already sends. A Cloudflare cache rule that overrides `no-store` could serve an old `status:"ok"` Safe as fresh forever. Fix: age from `generatedAt` like `AlertService` does.
  - Done: `SensorService.refresh` ages data from the snapshot's `generatedAt` (explicit-UTC string only; a future time is not clamped, `isStale` handles it). A body with a missing or invalid `generatedAt` is rejected whole (last good data stays and ages out; first fetch shows the existing "cannot reach" line). `fetchedAt` now means the time of the data.
  - **Owner-visible behaviour change:** a phone clock more than 1 min behind the server means sensor Safe is never shown; a phone clock more than 5 min ahead means every snapshot reads "may be out of date". Both fail on the safe side.
  - **Not fixed (note):** `StationStatus.fromJson` uses `DateTime.parse`, which throws on a bad `readingTime`, so one bad station rejects the whole snapshot (safe side, but loses the good stations).
- **R-F9 FIXED (2026-11-22, owner approved; `_disposed` guard in `AlertService` and `SensorService`, `AlertDetailScreen` wrapped in a `ListenableBuilder` with ended/stale derived from the service, `AlertService.now` getter added, test gaps closed):** (a) `notifyListeners` after `dispose()` when a fetch finishes late (`sensor_service.dart` ~123,127; `alert_service.dart` ~121,175): add a `_disposed` guard. (b) `alert_detail_screen.dart` does not listen to `AlertService`: if it stays open while data goes stale or the notice expires, it does not change; wrap the body in a `ListenableBuilder`. (c) Test gaps: an alert that expires while offline reaches history on the next download (`reason expired`, `endedAt == effectiveExpiry`) and a tick alone never writes history; first tick when the constructor fetch fails (0 notifies, level null); the exact 5:00 stale boundary; `alert_service_time_test.dart` ~256 uses demo-mode `SensorService()`; the comment at `sensor_stale_safe_test.dart` ~146 says the service does not notify, which is now wrong.
- **R-F10 (owner decisions 2026-11-23: (a) DONE (2026-11-23): `AlertService.futureSlack` = 5 min for alert data, sensors keep 1 min. (b) kept as is by owner decision. (c) DONE (2026-11-23; label th ถูกแทนที่ด้วยประกาศใหม่ approved by the owner 2026-11-23): the detail screen shows the live replacing update under the Ended banner (DRAFT label th 'ถูกแทนที่ด้วยประกาศใหม่', owner to approve Thai). (d) still open.) Original note (from the Opus review of R-F7/R-F9, 2026-11-22):** (a) Removing the future-time clamp (R-F7) means a phone clock 1-2 min BEHIND the server makes alert data permanently "may be out of date" (age about -1 to -2 min is past the 1 min slack): alerts still show and escalate, Home never shows "no notices", and nothing explains why. It fails on the safe side. Options: a larger slack for future times only (e.g. 5 min, inside the 30 min `staleAfter`), and/or a "check your phone clock" hint (owner wording). The sensor side of the same behaviour is recorded under R-F8. (b) A notice that vanishes from a fresh list with no history proof and not yet expired stays loud and live on the detail screen while Home has already dropped it. Over-warning is the right side of hard rule 1, so it was kept; the owner may want a draft line "no longer in the latest list". (c) "Ended: Replaced" on the detail screen says nothing about the replacing Update, which may still be live at the same or higher tier (predates Phase R; needs owner wording). (d) `_dataTime` accepts a zone-less time as local while the sensors require UTC (comes out stale, so safe, only inconsistent).

**Phase R done when:** analyze clean, CI test set green, goldens at 1x and 1.5x reviewed for every redesigned screen with Thai unclipped, no raw hex or size outside `AppTokens`/`AppPalette`, DESIGN.md matches the app.

---

## Phases B–D, F, G (outlines; each becomes full tasks when unblocked)

Phase E (more hazards: PM2.5, quake, landslide, heat, fire) was **deleted by the owner on 2026-11-18**: the product focuses on floods. Letters are kept so older notes still match. River-level sources (HII, RID) stay as flood inputs.

| Phase | Deliverable | Blocker (needs from owner) | Key acceptance |
|---|---|---|---|
| **B. Targeting and alert screens** | **Done 2026-11-18 (Tasks 6–11 plus one final-review fix wave; provinces only, districts deferred because TMD sends only province codes).** | Done: COD-AB downloaded by assistant; screen wording is DRAFT for the owner | Province-only TMD alert reaches users inside that province; point-in-polygon tests on the 102°E line and islands |
| **C. Hosting and delivery** | Deploy backend behind HTTPS on **Cloudflare** (owner's choice; the backend is a stdlib Python server with SQLite, so the route, such as Cloudflare Tunnel to a small machine or a Cloudflare Container, is a decision for the owner before any task is written); ops runbook; kill switch; cache + rate limit on `/flood-recurrence` (it is unauthenticated and spends the GISTDA key quota per call); expose a `skippedFiles` count and warning logs in the `/alerts` snapshot (a partial poll currently refreshes `generatedAt` even if one listed file, possibly a Cancel, failed to fetch); then push (FCM/APNs, topics by area code, coordinates never uploaded) | D1 host/budget; D2 Firebase project + package approval ("later") | Measured latency table (feed sent → shown) published in About; airplane-mode drill passes |
| **D. Content and trust** | Verified numbers 191/199/1155; Guide expert sign-off with reviewer and date shown; privacy notice, consent, data-sources page; crash reports opt-in | Owner: sources/phone calls, two reviewers, controller name, counsel | Release blockers in the Global Constraints cleared |
| **F. Sensors in the field** | Compile and run firmware on hardware; TLS in front; optional MQTT (D7); device registry; pilot next to an official gauge for a season | Hardware, site, pilot community | Documented error vs official gauge; sensors still do not raise area alerts (D15) until then |
| **H. Panic-readiness** | See "Phase H" above (Tasks H0–H9, from the 2026-11-19 persona audit). H2 and H4a ready; H1 after decision 15; H3, H4b, H5–H9 decision-gated | Decisions 9–15 in 1.6; real-person session (H0); Phase C for any real warning | First-time user sees area and nearest shelter without SOS; SOS call buttons at once; report says "not sent" before saving |
| **G. Reach and release** | Burmese/Lao/Khmer UI + fonts; store listings, signing, iOS Critical Alerts application; rescue coordination only if a responding partner exists | Translators, store accounts, partner, legal | PDPA review passed; acknowledged SOS is the only "received" state |

## Self-review

- **Spec coverage:** every Phase 1 deliverable in `docs/DEVELOPMENT_PLAN.md` §11 is either done (Part 1 §1.2), a Phase A task, or a Phase B–G outline with its blocker. Gaps found and recorded: no producer for alerts and `AlertService` has no URL (Task 4–5); staleness measured on phone time (Task 5); CAP references vs ids (Task 2); CI skips `test_gistda` (Task 4); phone sends GPS to Nominatim (§1.5, decision 5).
- **Stale spec items corrected:** the spec's G5 (SOS call/SMS), G6 (localisation, done with `context.tr`), G7/G8 (OSM tiles; now bundled MapLibre pack), G9 (shelters; now about 110 real ones), G11 (disclaimer; partly done) are closed or reduced. G1 (real data) is half done (sensors yes, alerts no).
- **Types match across tasks:** `parse_cap`/`base_id`/`merge_languages`/`build_snapshot`/`Poller` names are used identically in Tasks 1–4; the snapshot JSON keys equal those read by `OfficialAlert.fromJson`.
- **Phase H (2026-11-19):** every task cites an audit finding verified in code (F1 `home_screen.dart:60`, `report_screen.dart:101`; F5 `location_service.dart:41,94-98`; F10 `sensor_service.dart:71-81`). The audit's persona comments are simulated and are not used as evidence. Not verified: GPS timing on a real phone (H2 assumes the 10 s + 5 s limits in code), anything on screens the audit did not read (`alert_rules.dart`, alert detail/history, offline map).
- **Not verified:** golden tests (`design_test.dart`) were not run; firmware never compiled; real TMD Update/Cancel/Thai files not seen yet (Task 1 collects them, and Task 2 assertions must be filled from them).
