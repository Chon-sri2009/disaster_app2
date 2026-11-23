# Disaster Alert & Rescue: Project Summary

*For the owner and anyone new to the project. Written 2026-11-23 from the roadmap, CLAUDE.md and the code. Numbers are from the last recorded runs; see "How sure are we" at the end.*

## In one paragraph

A Thai-first phone app (Flutter) that warns people in Thailand about **floods** faster than the slow official channels, keeps working with no signal, and never says "Safe" when it does not know. It is backed by a small Python server and by cheap ESP32 water-level sensors. Today the app, the server and the official-alert pipeline are built and tested. **What is missing is the road to real users:** the server is not on the internet yet, there is no push notification, and several safety texts need your wording or an expert's sign-off.

## Who it is for

Residents of flood-prone areas (Bangkok first) and rescuers. Often frightened, outdoors at night or in rain, one hand free, low battery, weak or no signal. Thai is the main language, English the second. Some are elderly or have low vision.

**Success test:** a frightened person finds the alert level and the SOS button in under two seconds, with no signal.

## What the app does today

| Screen | What it gives the user |
|---|---|
| **Home** | The alert level for their area as a large band (Safe / Watch / Warning / Danger, each with icon + word + colour), their place in words, a press-and-hold SOS bar, nearest shelter, official notices tagged with the area they apply to |
| **Map** | Offline Bangkok map (bundled), about 110 shelters, community-sensor markers |
| **Call** | One-tap list of emergency lines (1669, 191, 1784 and others); the user always presses the final call or send |
| **Report** | Photo + location + note, saved **on the phone only** (the screen says it is not sent) |
| **Guide** | Offline first-aid and evacuation topics (your wording) |
| Settings, About | Language, data sources and credits, disclaimer (draft) |
| Alert detail and history | Full text of an official notice; a log of notices that have ended |

Also: a "this spot has flooded before" card from GISTDA flood-history data; Thai or English throughout; day and night themes; works at 1.5× text size.

## How it works

```
 ESP32 water sensors ──signed POST──►┐
                                     ├─► Python backend ──HTTPS JSON──► Phone app
 TMD official CAP alert feed ──poll─►┘   (stdlib only,                  (caches everything,
                                          SQLite)                       shows how old it is)
```

- **Sensors** send readings signed with a per-device key. The server re-checks range, jumps and stuck values. A silent or faulty sensor becomes "unknown", never "Safe".
- **Official alerts** come from the Thai Meteorological Department (TMD) CAP feed, the only source with an explicit reuse statement. The server turns each alert into one clean snapshot: Actual alerts only, cancellations and updates applied, polygons and province codes attached. If the poller dies, the snapshot's own timestamp ages and the phone says "may be out of date".
- **The phone** matches alerts to its location (by polygon, or by province when the alert has no polygon). Only an official alert can raise the level. Sensors show up as "community sensor, not an official gauge" and do not raise area alerts yet.

## The rules that never bend

1. **Never a false "Safe".** Stale, offline, faulty or missing data is "no data".
2. **Observations, not orders.** The app never issues an official warning or an evacuation order.
3. **Wording is yours.** Safety, first-aid and advice text is not reworded by us. New text is marked DRAFT until you approve it.
4. **Secrets stay on the server.** No API key in the app or in logs.
5. **GPS stays on the phone** unless you approve otherwise (open question below).
6. **Offline is normal, never red.** Every state is icon + word + colour; buttons at least 48 dp; text at least 16 sp.
7. **No official look or name.** No government emblems, no "T-Alert" naming.
8. **No new packages, no Firebase/push, no new services** without your yes.

## Where we are

**Done and tested**
- App: five tabs, Thai/English, four alert tiers, SOS hold, offline map, shelters, reports, guide.
- Server: sensor ingest and snapshot, GISTDA flood history, TMD alert pipeline with real recorded fixtures.
- Phase A (official alerts end to end) and Phase B (province targeting, alert detail, alert history).
- Phase R: visual redesign "Posted notice" (flat, ruled, no shadows, Sarabun only, nothing under 16 sp).
- Safety fixes found in review: stale sensor and alert data now age on a timer, work after the phone clock moves, and survive a hung network read.
- Panic-readiness fixes: SOS sheet opens at once; Report says "not sent" before saving; map labels follow the app language.

**Not done**
- The server is not deployed behind HTTPS (host chosen: Cloudflare; the route is undecided). Until then **no one can actually be warned.**
- No push notification when the app is closed.
- The app does not ask for location when it opens, so before SOS or Report is used it shows no nearest shelter.
- Sensors have never run on real hardware (firmware not yet compiled), and no season of comparison with an official gauge exists.

A simulated audit of 100 Bangkok residents (2026-11-19, reasoned from the code, not real user research) scored readiness for a real flood at **35/100, blocked**, mainly because there is no warning path in a release build. A five-person phone session with real people is still owed.

## What only you can unblock

| # | Decision or input | Unblocks |
|---|---|---|
| 1 | Backend host, route, budget, who deploys (Cloudflare chosen; route open) | Any real use |
| 2 | Confirm 191, 199, 1155 from an official page or a phone call | Release |
| 3 | Two expert reviewers for the Guide (medical, disaster management) | Release |
| 4 | App name, publisher, contact, data controller; privacy notice | Store release |
| 5 | Approve asking for location at app open (task H1) | Nearest shelter on first launch |
| 6 | Home level: show sensor level as "nearest sensor, distance" or keep as is (D15) | Task H3 |
| 7 | SOS sheet order (1669 vs 1784) and family numbers for SMS | Task H5 |
| 8 | Rewrite the Danger advice line ("Leave for a shelter now" reads like an order) | Hard-rule-2 conflict |
| 9 | Shelter status data source (open/full, pets, ramp, phone) | Task H7 |
| 10 | Guide section for a week indoors; family check-in; 7-day checklist | Tasks H8, H9 |
| 11 | Nominatim: address lookup sends GPS to OpenStreetMap; self-host, proxy, or disclose | Privacy notice |
| 12 | Update `PRODUCT.md` (stale on packages, offline tiles, push) | Agents read it as law |
| 13 | Approve new DRAFT Thai wording on Home tags, alert detail and history; pill text 14 sp vs the 16 sp rule | Phase B/R sign-off |
| 14 | Pilot area and size; agency permission letters; Firebase project | Phases C, F, G |

## What comes next (in order)

1. **Phase C: hosting and delivery.** Put the backend on HTTPS, add a kill switch and rate limit, run live against TMD, measure delay from "feed sent" to "shown on phone". Then push.
2. **Phase H: panic-readiness.** H1 (location at launch) after your yes; H3–H9 as you answer decisions 6–10.
3. **Phase D: trust.** Verified numbers, expert sign-off, privacy notice.
4. **Phase F: sensors in the field.** Compile the firmware, run on hardware, a season beside an official gauge.
5. **Phase G: reach.** More languages, store release; rescue coordination only if a partner will really respond.

Out of scope by your decision: other hazards (PM2.5, quake, landslide, heat, fire).

## How we work

Subagent-driven in three tiers: Opus for design and safety-critical logic and the final review; Sonnet implements; Haiku does lookups and boilerplate. From Phase B on, Opus advises and Sonnet implements. Every task is test-first (failing test, minimal code, passing test). Nothing is committed unless you ask, and nothing is pushed.

## How sure are we

- **Verified at last record:** `flutter analyze` clean; 115 Flutter tests (the CI set, which excludes the screenshot file) and 134 backend tests (backend run again 2026-11-23: all pass).
- **Not verified:** golden screenshots are rewritten by the test, not compared, so they are not proof; firmware never compiled; no run on a real phone; the live TMD feed has not been run behind HTTPS; the Flutter figures above were not re-run for this summary.
- **Uncommitted:** the Phase R redesign and later fixes are in the working tree, not yet committed.

*Sources: `docs/superpowers/plans/2026-11-18-disaster-app-roadmap.md` (the plan), `CLAUDE.md`, `docs/audits/2026-11-19-bangkok-flood-persona-audit.md`, `docs/OWNER_TODO.md`.*
