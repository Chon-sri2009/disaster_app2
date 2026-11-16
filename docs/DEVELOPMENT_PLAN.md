# Development plan: from mock prototype to a production disaster-warning app for Thailand

Written 2026-11-12. All sources were checked on that date unless marked otherwise.

**How to read the verification marks**

- **search** = found and read through web search results only (weakest).
- **fetch** = the page was fetched and read as static HTML/XML.
- **browser** = the page was opened and read in a real browser (needed for JavaScript pages).
- **[unverified]** = I could not confirm the claim; the reason is given next to it.
- **[login required]** = behind a sign-in or API-key registration; I did not sign up.

**Tool note.** The `/browser-use` skill was invoked but could not connect (Chrome was not running with remote debugging; I did not change that setting). Browser checks were done read-only in the Claude desktop app's built-in browser instead. No sign-in, form, download or cookie acceptance was performed.

**Rule followed throughout:** no endpoint, parameter, rate limit, licence term or app name appears here unless a page I read showed it. Where a page did not state something, this plan says "not documented".

---

## 1. Current state

### 1.1 What exists

| Area | Files | What it does today |
|---|---|---|
| App shell, 5 tabs | `lib/main.dart` | Home, Sensors, Map, Report, Guide. Bottom bar or rail by width. |
| Home | `lib/screens/home_screen.dart`, `lib/widgets/sos_hold_button.dart` | Level band, water meter, press-and-hold SOS. SOS reads GPS and offers a text share through `share_plus` (`home_screen.dart:97`). It does not call or send SMS. |
| Sensors | `lib/screens/sensors_screen.dart`, `lib/services/sensor_service.dart` | A timer emits a random reading every 2 s (`sensor_service.dart:17`). Level is derived from two fixed limits (`sensor_service.dart:35`). |
| Map | `lib/screens/map_screen.dart` | `flutter_map` with `tile.openstreetmap.org` tiles (`map_screen.dart:151`), user agent `com.example.disaster_app2` (`map_screen.dart:152`), shelter and sensor markers, offline banner. |
| Report | `lib/screens/report_screen.dart`, `lib/models/damage_report.dart` | Photo + GPS + note, saved on the phone only. |
| Guide | `lib/screens/guide_screen.dart`, `lib/data/guide_data.dart` | Static first-aid and evacuation topics (content owned by you). |
| Data | `lib/data/mock_data.dart` | Area "Riverside District", five invented shelters and three invented stations around Bangkok (13.7563, 100.5018). |
| Alert model | `lib/models/alert_level.dart` | Three levels (Safe / Watch / Danger) with their own colours and English advice. The theme has four tiers (DESIGN.md, `lib/theme/`). |
| Storage | `lib/services/storage_service.dart` | `shared_preferences` JSON strings for shelters, reports, last position. |
| Location | `lib/services/location_service.dart` | One-shot foreground GPS with 10 s limit and saved-position fallback. |
| Theme | `lib/theme/app_palette.dart`, `app_tokens.dart`, `app_theme.dart` | "Flood gauge board" tokens, Sarabun font. |
| Tests | `test/design_test.dart`, `test/offline_map_test.dart`, `test/widget_test.dart`, `test/goldens/` | Contrast pairs, overflow at text scales, tap targets and labels, SOS hold, 13 goldens, offline map banner. |

Observed but not run: `test/failures/` holds diff images for `home_phone-390x844`, `home_tablet-820x1180`, `sensors_390x844` and `sensors_over_limit_390x844`. Either those goldens are stale or the last run failed. Check before Phase 1 starts. The folder is not a git repository, so there is no history to consult.

### 1.2 Gap list, mock to production

| # | Gap | Evidence |
|---|---|---|
| G1 | No real alert or sensor data; no network layer at all | `sensor_service.dart`, `mock_data.dart` |
| G2 | Alert model has 3 levels, design has 4, agencies use 4 to 5 | `alert_level.dart`, section 2 |
| G3 | Alert level is one global value, not tied to the user's province / amphoe / tambon | `mock_data.dart:13` |
| G4 | No push, no background delivery; an alert is only seen with the app open | PRODUCT.md out-of-scope list |
| G5 | SOS cannot call 1669 / 191 or send SMS; no emergency numbers anywhere in `lib/` | grep of `lib/` |
| G6 | All copy is English; no localisation framework | PRODUCT.md |
| G7 | Map tiles blank offline; the current tile host forbids offline prefetch (section 5.1) | `map_screen.dart:151` |
| G8 | Placeholder user agent and app id `com.example.disaster_app2`; OSM policy needs a distinct, stable one | `map_screen.dart:152`, https://operations.osmfoundation.org/policies/tiles/ |
| G9 | Shelters are invented; no real shelter dataset wired | `mock_data.dart:30` |
| G10 | Storage is one JSON string per list; will not hold alert history, cached layers, or photos at scale | `storage_service.dart` |
| G11 | No privacy notice, consent, disclaimer or data-source attribution screens | all screens |
| G12 | No "stale since" handling for remote data (principle 5 only covers "mock data" caption) | DESIGN.md components |
| G13 | No ESP32 ingest path | PRODUCT.md |
| G14 | No release setup: signing, store listings, crash reporting, CI | repo |

---

## 2. Hazards in scope for Thailand

Alert levels below are the agency's own, as shown on the cited page. Where a page did not show levels, the cell says so. Mapping these to the app's four tiers is decision D3.

| Hazard | Authoritative Thai agency | Data available (verified) | Alert levels the agency uses |
|---|---|---|---|
| River flood | Hydro-Informatics Institute (HII) / National Hydroinformatics Data Center; Royal Irrigation Department (RID); ONWR for national coordination | Station water level (m MSL), bank level, trend, per province and basin on https://www.thaiwater.net/water/wl (browser). RID telemetry station dataset listed at https://data.go.th/en/dataset/telerid-rid (fetch). | thaiwater.net shows 5 classes by % of channel capacity: ≤10 critically low, >10–30 low, >30–70 normal, >70–100 high, >100 overbank (browser). ONWR levels: not verified. |
| Flash flood | DMR (flash-flood guidance in DMRLIS); TMD rain warnings; DDPM/NDWC for the public warning | DMRLIS flash-flood forecast map, current / 1 day / 3 days, by tambon: https://dmrlis.dmr.go.th/ (fetch, browser). 24-h rain per station on https://www.thaiwater.net/ (browser). | DMRLIS flash flood: 4 levels, very high to low (fetch). thaiwater 24-h rain bins: >0–10, >10–20, >20–35, >35–50, >50–70, >70–90, >90 mm, labelled light / moderate / heavy / very heavy (browser). |
| Urban flood | Bangkok Metropolitan Administration (BMA) for Bangkok; DDPM elsewhere | [unverified] BMA drainage feeds were not checked this session. | Not documented in sources read. |
| Tropical storm | Thai Meteorological Department (TMD) | CAP alert feed (fetch): https://www.tmd.go.th/en/api/xml/CAP. `WeatherWarningNews` service listed at https://data.tmd.go.th/api/index1.php (fetch). Storm panel on thaiwater.net (browser). | CAP severity / urgency / certainty inside each alert file; values not inspected this session. Item titles seen: "Heavy Rain", "Very Heavy Rain". |
| Landslide | Department of Mineral Resources (DMR) | DMRLIS landslide forecast by tambon, current / 1 / 3 days; daily geohazard reports and volunteer-network notices on https://www.dmr.go.th/ (fetch). "API services" page exists at https://dmrlis.dmr.go.th/th/api-services (link seen in browser; page not read). | 5 levels: very high, high, medium, low, very low, plus "rain below warning level" (fetch, browser). |
| Earthquake | TMD Earthquake Observation Division | Recent-event table (time, magnitude, lat, long, depth, region in Thai and English) at https://earthquake.tmd.go.th/ (fetch). RSS feeds listed at https://earthquake.tmd.go.th/rss.html (fetch). `DailySeismicEvent` in the TMD API list (fetch). | No classification text on the page. T-Alert trigger: domestic magnitude 4.0 or higher (https://thailand.prd.go.th/en/content/category/detail/id/52/iid/426007, fetch). |
| Tsunami (Andaman coast) | National Disaster Warning Center (NDWC) under DDPM; TMD issues earthquake information | NDWC site shows current notices as text: https://ndwc.disaster.go.th/ndwc/home (browser). No public feed found. | T-Alert trigger: Andaman Sea earthquake above 7.5 (same PRD article, fetch). NDWC colour levels: [unverified], not shown on pages read. |
| PM2.5 / haze | Pollution Control Department (PCD) | Station JSON with PM2.5, PM10, O3, CO, NO2, SO2, AQI, lat/long, Thai and English names; 174 stations, hourly timestamp seen (browser): http://air4thai.pcd.go.th/services/getNewAQI_JSON.php | 5 AQI levels on https://air4thai.pcd.go.th/webV3/#/Home: very good, good, moderate, starting to affect health, affecting health (browser). T-Alert trigger: PM2.5 at 75 µg/m³ or higher (PRD article, fetch). |
| Wildfire | GISTDA (satellite hotspots, burnt area); Department of National Parks for response [unverified] | GISTDA Disaster Platform https://disaster.gistda.or.th/ (browser). Burnt-area API dataset listed on GISTDA open data (search). Fallback: NASA FIRMS (USA). | No level scheme shown. Hotspot counts only. |
| Heatwave | TMD (heat index) and Department of Health, MOPH (health warning levels) | Levels described in an ONEP article that cites TMD and the Department of Health: https://www.onep.go.th/?p=112050 (fetch). Primary DOH page not found: [unverified]. | 4 levels by heat index: watch 27.0–32.9 °C, warning 33.0–41.9, danger 42.0–51.9, extreme danger 52+ (fetch, secondary source). |
| Drought | ONWR (coordination), RID (reservoirs), GISTDA (drought-recurrence layer) | GISTDA drought-recurrence point API listed on open data (search). ONWR pages not read: [unverified]. | Not documented in sources read. |

National public-warning layer on top of all hazards: **T-Alert / Cell Broadcast**, run by DDPM through NDWC with NBTC, MDES and operators AIS, True and NT. Launched 22 September 2025; eight hazard types at launch (earthquake, tsunami, windstorm, flood, landslide, cold spell, PM2.5, violence in public spaces) (https://thailand.prd.go.th/en/content/category/detail/id/52/iid/426007, fetch). A nationwide test was scheduled for 20 January 2026 at 14:00; phones need iOS 18 or Android 11 or later; the message shows in Thai and English and contains no links (https://thailand.prd.go.th/en/content/category/detail/id/48/iid/466646, fetch). True's blog says five alert categories exist; they were not listed in what I read: [unverified] (https://www.true.th/blog/en/cell-broadcast-service/, search).

---

## 3. Official warning and data sources

Verified date is 2026-11-12 for every row. Confidence: **High** = official page read and the feed itself seen; **Medium** = official page read but terms or feed not confirmed; **Low** = search only or page failed.

### 3.1 Thai sources

| Agency | Hazard | Feed type | Format | Update frequency | Access, licence and terms | URL | Verified by | Confidence |
|---|---|---|---|---|---|---|---|---|
| TMD | Storm, heavy rain, weather warnings | CAP index | RSS 2.0 linking to CAP XML files | Feed built 12 Nov 2026 07:41; 8 items from 9–11 Nov 2026 | No key. `<copyright>` element says "public domain". No other terms on the feed. | https://www.tmd.go.th/en/api/xml/CAP | fetch | High |
| TMD | Same, Thai language | CAP index | RSS/CAP | not checked | Listed in the WMO register; the Thai feed itself was not fetched: [unverified live] | https://www.tmd.go.th/api/xml/CAP | fetch (register only) | Medium |
| TMD | Weather obs, forecast, warning news, earthquakes | API (17 services) | XML documented; other formats not stated | Varies: 3-hourly obs; daily forecast at 06, 12, 17, 23 h; others not stated | Page shows no licence or terms. Example links carry shared demo credentials. Served over `http://`. NWP forecast API needs registration: [login required] | https://data.tmd.go.th/api/index1.php | fetch | Medium |
| TMD Earthquake Division | Earthquake | Web table + RSS | HTML; RSS 2.0 (one "Basic Geo") | not documented | Footer: all rights reserved, Earthquake Monitoring Division. No feed terms. Feed files themselves not fetched. | https://earthquake.tmd.go.th/ and https://earthquake.tmd.go.th/rss.html | fetch | Medium |
| DDPM | All hazards: situation reports, daily warning reports | Web | HTML | Daily reports seen (12 Nov 2026 06:00) | No API or RSS found on the home page. © notice only. | https://www.disaster.go.th/home | browser | Medium |
| DDPM | Public alert web view (Thai Disaster Alert) | Web app | JavaScript page | not documented | No terms seen. Version label v.0.0.4. | https://tdaweb.disaster.go.th/tda/AlertHome | browser | Medium |
| NDWC (under DDPM) | Tsunami, multi-hazard notices | Web | JavaScript page | Current notice seen | No CAP feed. WMO register lists NDWC with a blank CAP URL (https://alertingauthority.wmo.int/authorities.php?recId=272, fetch). | https://ndwc.disaster.go.th/ndwc/home | browser | Medium |
| DDPM / NBTC / AIS, True, NT | All (T-Alert Cell Broadcast) | Cell Broadcast | Phone system alert | Event driven | Not an API. An app cannot send, receive or read these. | https://thailand.prd.go.th/en/content/category/detail/id/52/iid/426007 | fetch | High (existence); n/a (integration) |
| HII / National Hydroinformatics Data Center | Flood, rain, storm, air quality overview | Web dashboard | JavaScript; calls `api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load` | Station times 06:00–07:30 seen at 07:30 | The API host is called by the site but has **no public documentation or terms that I found**. Treat as not licensed for third-party use until HII confirms in writing. | https://www.thaiwater.net/water/wl | browser | High (data exists); Low (right to use) |
| HII | Water data exchange standard | Specification | API spec for agencies | n/a | A standard for data providers, not a public endpoint. Auth section not read. | https://standard.thaiwater.net/?p=6830 | fetch | Medium |
| HII | Rain, water level, forecast datasets | Open data catalogue (CKAN) | not stated | not stated | 40 datasets. Licence, formats and API not stated on the landing page. Login link present. | https://data.hii.or.th/ | fetch | Medium |
| HII | Agency home | Web | HTML | n/a | Confirms HII built the National Hydroinformatics Data Center and the ThaiWater app. | https://www.hii.or.th/ | fetch | High |
| RID | River level telemetry | Dataset listing | HTML resource; "Data API" option shown without a URL | "Real-time" | "License not specified". Maintained 20 Jun 2024. | https://data.go.th/en/dataset/telerid-rid | fetch | Medium |
| RID | Water situation sites | Web | not checked | not checked | [unverified]: `wmsc.rid.go.th`, `swoc.rid.go.th` and hotline 1460 came from news results only. The RID home page returned only the agency name to fetch. | https://www.rid.go.th/ | fetch (home), search (rest) | Low |
| GISTDA | Flood extent, hotspots, drought, PM | Web platform | JavaScript | Weekly flood summaries seen (20–26 Oct 2026) | Sign-in link present; landing content is public. Cookie banner declined-by-default (not accepted). Notice: hotspots switch to NOAA-20 for 2027 because Suomi NPP VIIRS data stops in November 2026. | https://disaster.gistda.or.th/ | browser | High |
| GISTDA | Flood-recurrence layer (2011–2023) by point or polygon | API via API Gateway | not stated | Unknown | Licence "Open Data Common". **API key required**: [login required], register at `api-gateway.gistda.or.th/v2`. | https://opendata.gistda.or.th/en/dataset/disasters-01 | fetch | Medium |
| GISTDA | Drought recurrence, burnt area (latest) | API via API Gateway | not stated | Burnt area: daily (per search result) | Same gateway and key. Dataset pages not opened: [unverified detail] | https://opendata.gistda.or.th/en/dataset/disasters-02 , https://opendata.gistda.or.th/en/dataset/disasters-04 | search | Low |
| DMR | Landslide and flash-flood forecast by tambon | Web map; API page exists | JavaScript | Current, +1 day, +3 days | Download terms and API terms not documented on pages read. | https://dmrlis.dmr.go.th/ | fetch, browser | Medium |
| DMR | Daily geohazard reports, notices, GIS portal links | Web | HTML, PDF | Daily (5–11 Nov 2026 seen) | Links to `gisportal.dmr.go.th`, `data.dmr.go.th`, and DMR's data.go.th page. Landslide-risk village dataset not located: [unverified] | https://www.dmr.go.th/ | fetch | Medium |
| PCD (Air4Thai) | PM2.5, AQI | JSON service | JSON | Hourly timestamp seen (12 Nov 2026 07:00) | No key. **No terms shown.** The site links a "procedure for requesting air quality data", which suggests formal requests are expected. Certificate chain failed in fetch; opened in browser. | http://air4thai.pcd.go.th/services/getNewAQI_JSON.php | browser | High (data); Low (terms) |
| DGA open data portal | Many | Catalogue | CSV, others | Per dataset | 578 results for "ภัยพิบัติ". Licence shown per dataset; portal default not stated on the page. | https://data.go.th/ | fetch | Medium |
| Songkhla Provincial Office | Shelters (Songkhla only) | Dataset | CSV | Yearly; updated 17 Jun 2025 | "Open Data Common". Coordinates not confirmed. | https://data.go.th/en/dataset/dpm06 | fetch | Medium |

### 3.2 Emergency numbers

| Number | Service | Evidence | Verified by | Confidence |
|---|---|---|---|---|
| 1669 | Emergency medical (NIEMS) | NIEMS home shows "เจ็บป่วยฉุกเฉิน โทร.1669": https://www.niems.go.th/ | fetch | High |
| 1784 | DDPM disaster hotline | DDPM site title is "1784 : กรมป้องกันและบรรเทาสาธารณภัย": https://www.disaster.go.th/ | browser | High |
| 191 | Police | Not shown on the Royal Thai Police home page I loaded (https://www.royalthaipolice.go.th/). Confirmed only in news and a Public Relations Department result (https://www.prd.go.th/th/content/category/detail/id/9/iid/244070). | search | Medium: confirm on an official page before release |
| 199 | Fire (Bangkok) | The BMA fire department domain is `bangkokfire199.com`; only its splash page loaded. News sources agree. | browser (splash), search | Medium: confirm coverage outside Bangkok |
| 1155 | Tourist Police | "1155" present in the page source of https://www.touristpolice.go.th/ ; visible text did not load. | browser | Medium |
| 1182 | TMD weather / earthquake enquiries (press 3) | https://earthquake.tmd.go.th/ | fetch | High |
| 1650 | PCD hotline | https://air4thai.pcd.go.th/webV3/#/Home | browser | High |
| 1664 | Thai Red Cross | https://www.redcross.or.th/ | fetch | High |
| 1460 | RID | news results only | search | Low |

One search result attributed 1784 to a different department; the DDPM site itself settles it.

### 3.3 International sources (use only as fallback or for regional hazards)

| Organisation (country) | Hazard | Feed type | Format | Update frequency | Access, licence and terms | URL | Verified by | Confidence |
|---|---|---|---|---|---|---|---|---|
| USGS (USA) | Earthquake | API | GeoJSON, QuakeML, CSV, KML, text | Near real time | No key. `limit` max 20000. The page asks automated apps to prefer the real-time GeoJSON feeds. Legal page linked, not read. | https://earthquake.usgs.gov/fdsnws/event/1/ | fetch | High |
| GDACS (UN OCHA + European Commission JRC) | Earthquake, cyclone, flood | RSS | RSS | "Every 6 minutes" | Terms-of-use page linked, not read. JRC liability disclaimer in footer. | https://www.gdacs.org/feed_reference.aspx | fetch | High (feeds); Medium (terms) |
| GDACS | Same | API | Swagger page | n/a | Page loaded but endpoints did not render: [unverified] | https://www.gdacs.org/gdacsapi/swagger/index.html | browser | Low |
| NOAA PTWC (USA) | Tsunami | Atom + CAP | XML | Event driven | **Covers the Pacific and Caribbean. The page lists no Indian Ocean product**, so it is not a source for the Andaman coast. | https://www.tsunami.gov/?page=productRetrieval | fetch | High |
| IOTWMS service providers: INCOIS (India), BMKG (Indonesia), JATWC / BoM (Australia) | Tsunami, Indian Ocean | Bulletins to national centres | not documented | Event driven | National warnings stay each state's responsibility. A public machine feed was not found. The INCOIS page I tried returned 404: [unverified] | https://rtsp.bmkg.go.id/ | search | Low |
| AHA Centre (ASEAN) | Regional situation, all hazards | Web products | HTML, PDF | Flash updates per event; weekly update | No RSS or data feed listed. | https://ahacentre.org/ | fetch | Medium |
| WMO Register of Alerting Authorities | Authority check | Register | HTML | n/a | Lists TMD (OID 2.49.0.0.764.0, CAP feeds) and NDWC (OID 2.49.0.0.764.1, no feed). | https://alertingauthority.wmo.int/authorities.php?recId=164 | fetch | High |
| WMO Severe Weather Information Centre (run by Hong Kong Observatory) | CAP warnings in effect, cyclone tracks | Web | HTML | not documented | Aggregates member CAP warnings. No public API documented. A separately named "WMO Alert Hub" endpoint was not confirmed: [unverified] | https://severeweather.wmo.int/ | fetch | Medium |
| NASA FIRMS (USA) | Fire hotspots | API | CSV, KML | NRT / URT | `MAP_KEY` is part of the URL pattern `/api/area/csv/[MAP_KEY]/[SOURCE]/[AREA_COORDINATES]/[DAY_RANGE]`: [login required] to obtain a key. Transaction limit not stated on the pages read. Sources include MODIS, VIIRS S-NPP, NOAA-20, NOAA-21. | https://firms.modaps.eosdis.nasa.gov/api/area/ | fetch, browser | High |
| Copernicus EMS (EU) | Flood and fire mapping on request | Web; activation products | Geopackage mentioned | Per activation | Free of charge. Only authorised users can trigger. Licence text not read. No API documented on the page. | https://mapping.emergency.copernicus.eu/ | fetch | Medium |

### 3.4 What this means

1. The only Thai source that is both machine-readable and carries an explicit reuse statement is the **TMD CAP feed**. Build the MVP on it.
2. Water level, PM2.5 and landslide data are visible and machine-readable, but **none shows terms that permit redistribution in a third-party app**. Each needs a written request to the agency before production use (decision D5). You have told me not to contact agencies, so this plan stops at listing them.
3. There is **no public feed for tsunami warnings** for the Andaman coast. The app must not present itself as a tsunami warning channel. It can point to T-Alert / Cell Broadcast and to NDWC.
4. Two sources need keys (GISTDA gateway, NASA FIRMS). Keys must live on a server, never in the app binary.

---

## 4. Sources for advice and safety content

This section proposes sources and a review process only. **No existing Guide or advice wording is changed or rewritten by this plan.**

### 4.1 Candidate sources

| Source | What it offers | URL | Verified by | Note |
|---|---|---|---|---|
| NIEMS (Thailand) | Emergency medical authority; infographic section at `/infographic` | https://www.niems.go.th/ | fetch | Infographic content not read. |
| Thai Red Cross Society | First-aid training, online learning, AED locator app, "Phon Phai" disaster-report app | https://www.redcross.or.th/ | fetch | No public first-aid manual link on the home page. |
| DDPM public guidance | "ปภ. แนะนำ" items and publications | https://www.disaster.go.th/home | browser | Topics seen were road-safety items; hazard guidance pages not located. |
| Department of Health / MOPH (Thailand) | Heat and PM2.5 health advice | [unverified] primary page not found; cited by https://www.onep.go.th/?p=112050 | fetch (secondary) | Find the primary notice before citing. |
| IFRC Global First Aid Reference Centre (international) | International first aid, resuscitation and education guidelines 2020 | https://www.globalfirstaidcentre.org/first-aid-guidelines-2020/ | browser | Reuse terms not read. |
| Ready.gov / FEMA (USA) | Hazard-by-hazard preparedness pages | https://www.ready.gov/be-informed | fetch | No reuse statement on the page. US context; adapt with care. |
| WHO (international) | Health-emergency guidance | [unverified] not opened this session | — | Fallback only. |

### 4.2 Review process (proposal)

1. **Inventory.** List every sentence in `lib/data/guide_data.dart` and every `advice` string in `lib/models/alert_level.dart` in a spreadsheet: id, current text, source (blank today), reviewer, date, status. Nothing is edited at this step.
2. **Source matching.** For each row, you (the content owner) attach the Thai source that supports it, or mark "no source".
3. **Expert review.** One medically qualified reviewer for first aid (NIEMS- or Red Cross-trained instructor) and one disaster-management reviewer (DDPM-trained officer or equivalent). Each signs off per row: keep, change (they propose wording to you), or remove.
4. **Thai wording** is written by you and checked by the same reviewers in Thai, not translated from English after the fact.
5. **Version stamp.** The Guide screen shows "reviewed by, date" and each topic stores a content version so stale offline copies can be detected.
6. **Re-review** yearly and whenever a cited source publishes a new edition.
7. Rows with no source and no reviewer sign-off do not ship.

---

## 5. Maps and geodata (Thailand)

### 5.1 Base tiles and offline strategy

Current tiles come from `tile.openstreetmap.org`. Its policy (https://operations.osmfoundation.org/policies/tiles/, fetch) says: use a distinct, stable user agent; show attribution visibly; honour cache headers; and **offline "save area" features, prefetching and pre-seeding are not permitted** on that host. Access can be withdrawn without notice. So the present setup cannot meet the offline-first goal.

Options (decision D6):

| Option | Offline | Cost and effort | Tradeoff |
|---|---|---|---|
| A. Keep OSM tiles, online only; ship a bundled low-zoom Thailand overview image | Country overview only | None | Map is close to useless offline. Policy-compliant. |
| B. Self-hosted or CDN-hosted **PMTiles** archive of Thailand built from OSM data, plus downloadable per-province extracts | Yes | New packages for reading PMTiles / vector tiles [package names not verified on pub.dev this session]; hosting a multi-GB file | PMTiles is a single-file tile archive readable over HTTP range requests (https://docs.protomaps.com/pmtiles/, fetch). OSM data is ODbL; attribution required. Best fit for offline-first. |
| C. Commercial tile provider that permits offline download | Yes | Monthly fee; SDK lock-in | Terms differ per provider; none evaluated here. |
| D. `flutter_map_tile_caching` plugin | Yes, technically | One package | **GPL-3.0**; the author sells a proprietary licence (https://pub.dev/packages/flutter_map_tile_caching, fetch). It also does not solve the tile host's terms. |

Recommendation: **B**, staged. MVP ships option A (no new package) with the shelter list still working without tiles, as it does today. Phase 2 adds per-province offline packs.

### 5.2 Admin boundaries

| Source | Levels | Licence | URL | Verified by |
|---|---|---|---|---|
| OCHA HDX COD-AB Thailand (source: Royal Thai Survey Department, acquired through ICRC) | 77 provinces, 928 districts, 7,425 tambons; P-coded; Thai and English names | CC BY-IGO | https://data.humdata.org/dataset/cod-ab-tha | browser (fetch returned 403) |
| DOPA (Department of Provincial Administration) | Official province / amphoe / tambon codes | [unverified]: only DOPA population datasets on data.go.th turned up in search | https://data.go.th/ | search |
| Royal Thai Survey Department direct | Authoritative boundaries | [unverified]: not opened | — | — |

Notes on COD-AB from its page: boundaries date from 1 January 2022, reviewed 30 October 2025; the Thai name of district TH1008 (Pom Prap Sattru Phai) is wrong in the data and must be corrected to ป้อมปราบศัตรูพ่าย; file sizes are large (GeoJSON 416.5 MB, SHP 359.2 MB), so geometry must be simplified before bundling. Files were not downloaded this session.

Use: bundle simplified province and amphoe polygons; fetch tambon polygons per province on demand. Record the P-code to DOPA-code mapping once DOPA codes are confirmed, because Thai agencies key their data on DOPA codes.

### 5.3 Shelters and evacuation centres

No national open shelter dataset with coordinates was found. One provincial dataset exists: Songkhla temporary shelters, CSV, "Open Data Common", yearly, coordinates not confirmed (https://data.go.th/en/dataset/dpm06, fetch). The Public Relations Department points to a Bangkok district shelter list by QR code (https://www.prd.go.th/th/content/category/detail/id/33/iid/545241, search).

Plan: treat shelters as curated data. Start with one pilot province, collect from the provincial DDPM office (needs your approval to contact), store source and "last confirmed" date per shelter, and show that date in the app (principle 5).

### 5.4 Flood-risk layers and hydro stations

- Flood recurrence 2011–2023: GISTDA API by point or polygon, key required (https://opendata.gistda.or.th/en/dataset/disasters-01, fetch).
- Current flood extent: weekly satellite summaries on https://disaster.gistda.or.th/ (browser); machine access not confirmed.
- Hydro stations: thaiwater.net loads a station list and province and basin boundaries from its own JSON files (seen in browser network log); reuse terms not documented.
- RID telemetry stations: https://data.go.th/en/dataset/telerid-rid (fetch), licence not specified.

### 5.5 Coordinate systems

- The app, `flutter_map`, GPS and CAP all use **WGS84 latitude/longitude (EPSG:4326)**. Store and exchange in this only.
- Thai agency shapefiles and paper maps are often in **UTM zone 47N or 48N** on WGS84 (EPSG:32647, 32648); the zone boundary is at 102°E, which runs through the country. Older data may use the Indian 1975 datum, which is offset from WGS84 by hundreds of metres. [These are general geodesy facts, not taken from a page read this session; confirm each dataset's `.prj` file on import.]
- Reproject on the server at import time. The phone never reprojects.
- CAP polygons are "lat,lon" pairs; GeoJSON is "lon,lat". Add a test for axis order.

### 5.6 Place names

COD-AB carries Thai and English names per level. English spellings of Thai places vary between agencies; match on codes, never on names. Show Thai first, English second, and keep both in the search index.

### 5.7 Attribution to show in the app

| Source | Attribution text needed |
|---|---|
| OpenStreetMap tiles or data | "© OpenStreetMap contributors", visible on the map (policy above) |
| COD-AB | Credit OCHA and Royal Thai Survey Department, CC BY-IGO |
| TMD CAP | Name TMD as the issuing authority on every alert |
| GISTDA, PCD, HII, DMR, RID | To be set by the permission each agency grants (D5) |

---

## 6. Design examples

### 6.1 Pattern libraries

| Library | Link | Verified by | What to borrow | Conflicts with DESIGN.md |
|---|---|---|---|---|
| Material 3 components | https://m3.material.io/components | browser | Navigation bar and rail, dialogs, snackbars, badges; state layers; touch-target guidance | M3 defaults use tonal elevation and dynamic colour. DESIGN.md is flat, one accent, fixed tier colours. Keep tokens; do not adopt dynamic colour. |
| Apple HIG: Notifications | https://developer.apple.com/design/human-interface-guidelines/notifications | browser | Consent before notifying; glanceable content; urgency levels | None in principle. iOS system chrome will differ from the gauge-board look; accept it. |
| OCHA humanitarian icons | https://brand.unocha.org/d/xEPytAUjC3sH/icons | [unverified]: page returned an error | Hazard pictograms that responders already recognise | Tier icons are fixed (check, eye, triangle, octagon). Use OCHA icons for hazard type only, never for tier. |
| Mobbin | https://mobbin.com/ | [unverified]: public page returned 403 | Onboarding, permission-priming and settings flows | Most examples are consumer-app styling with shadows and gradients. |
| Dribbble search "disaster alert app" | https://dribbble.com/search/disaster-alert-app | browser | Layout ideas for alert lists and map overlays | Concept shots, rarely accessible: low contrast, colour-only states, small text. Treat as mood only. |
| Behance search "disaster alert app" | https://www.behance.net/search/projects?search=disaster%20alert%20app | browser | Full case studies showing flows end to end | Same caution as Dribbble. |

### 6.2 Existing apps (names, publishers and update dates read from Google Play in the browser, 2026-11-12)

| App (store name) | Publisher | Updated | Link | What to borrow | Conflicts with DESIGN.md |
|---|---|---|---|---|---|
| THAI DISASTER ALERT | Department of Disaster Prevention and Mitigation | 27 Apr 2026; 100K+ | https://play.google.com/store/apps/details?id=com.THAIDAlert.DPM | Province selection for alerts; Thai and English; hotline list. Official wording for hazard names. | Not assessed visually. Do not copy its name or look; this app must not appear official. |
| Thai Disaster Alert (iOS) | Department of Disaster Prevention and Mitigation | Version 3.0.16, 28 Apr | https://apps.apple.com/th/app/thai-disaster-alert/id1593150344 | Same | Same |
| DPM Reporter | Department of Disaster Prevention and Mitigation | 1 Aug 2024; 50K+ | https://play.google.com/store/apps/details?id=com.depthfirst.dpm.reporter | How an official incident-report flow is structured | The Report screen here is local-only; do not imply reports reach DDPM. |
| ThaiWater | Hydro-Informatics Institute (Public Organization) | 30 Oct 2026; 100K+ | https://play.google.com/store/apps/details?id=mobile.nhc.thaiwater | Station cards with bank level and "below bank by X m"; five-class water status | Uses many colours per map layer; here one colour per tier only. |
| Air4Thai | Pollution Control Department, Thailand | 5 Aug 2026; 500K+ | https://play.google.com/store/apps/details?id=com.kathistudio.air4thaimobile | AQI wording in Thai; station-nearest-me pattern | Five-colour AQI scale would add colours outside the tier set. Show the agency's word, in the nearest tier colour (D3). |
| EarthquakeTMD - Thailand | Earthquake Observation Division, TMD | 31 Oct 2026; 500K+ | https://play.google.com/store/apps/details?id=app.android.tmd.earthquake.earthquaketmd | Event list fields; Thai and English region names | — |
| NERV Disaster Prevention (Japan) | Gehirn Inc. | 16 Sep 2026; 1M+ | https://play.google.com/store/apps/details?id=app.nerv | Speed-first alert timeline; strong accessibility focus; location-scoped alerts | Dark, dense, high-tech look. DESIGN.md is light theme only, large and sparse. |
| Safety tips (Japan; JNTO-supervised app for visitors) | RC Solution Co. | 2 Nov 2026; 500K+ | https://play.google.com/store/apps/details?id=jp.co.rcsc.safetyTips.android | Multilingual alerts for non-native speakers; phrase cards to show to locals. Useful model for migrant workers. | — |
| FEMA (USA) | Federal Emergency Management Agency (FEMA) | 14 Aug 2026; 1M+ | https://play.google.com/store/apps/details?id=gov.fema.mobile.android | Multiple saved locations; shelter finder; preparedness checklists | US-specific services. |
| Emergency: Severe Weather App (USA) | American Red Cross | 9 Nov 2026; 500K+ | https://play.google.com/store/apps/details?id=com.cube.arc.hzd | "I'm safe" message; offline preparedness content per hazard | Photo-led cards and red brand colour. Red here means Danger only. |
| MyShake Earthquake Alerts (USA) | UC Berkeley Seismological Laboratory | 27 Aug 2026; 1M+ | https://play.google.com/store/apps/details?id=edu.berkeley.bsl.myshake | Full-screen "Drop, cover, hold on" alert; honest text about alert limits | Earthquake early warning needs a seismic network Thailand's app cannot claim. Borrow the screen pattern, not the promise. |

Names, publishers, update dates and download bands are as shown in the store. The apps were not installed, so the "what to borrow" and "conflicts" columns describe features from general knowledge of these apps, not from screens checked this session: [unverified]. The same applies to "JNTO-supervised" for Safety tips. Confirm by installing each app yourself before design work starts.

---

## 7. Architecture

### 7.1 Phone-direct feeds or a backend aggregator

| | Phone-direct | Backend aggregator |
|---|---|---|
| New moving parts | None on a server | One small service + storage + scheduler |
| API keys (GISTDA, FIRMS) | Would ship inside the app: not acceptable | Stay on the server |
| TMD API over `http://` with shared demo credentials | Phone would need cleartext traffic allowed | Server fetches; phone uses HTTPS only |
| Agency terms, rate limits | Every phone hits the agency | One polite poller, cached |
| Push when the app is closed | Not possible | Possible |
| Agency site down | App shows nothing new | Serve last good snapshot with its age |
| Data shape | Five formats parsed in Dart | One normalised JSON |
| Cost, operations | Zero | Small but real: hosting, monitoring, on-call |

**Recommendation: a backend aggregator**, kept minimal: a scheduled job that pulls each source, normalises to one alert schema, writes a static JSON snapshot per province to object storage behind a CDN, and sends push messages. The phone downloads snapshots over HTTPS and caches them. This is the only design that allows push, keeps keys off phones and survives agency outages. It breaks the "no backend" state in PRODUCT.md, so it is decision D1.

A phone-direct read of the TMD CAP feed is technically possible with no new package (`dart:io` `HttpClient`, plus hand-parsing or an XML package). It is the fallback if you reject D1, and gives foreground-only alerts.

### 7.2 Normalised alert schema and CAP parsing

Server side. For each CAP `<alert>`: keep `identifier`, `sender`, `sent`, `status`, `msgType`, `references`; per `<info>` keep `language`, `event`, `urgency`, `severity`, `certainty`, `effective`, `onset`, `expires`, `headline`, `description`, `instruction`; per `<area>` keep `areaDesc`, `polygon`, `geocode`. Rules:

- Drop `status` other than `Actual` from user-facing output (keep `Test` and `Exercise` for a debug view).
- `msgType` `Update` and `Cancel` replace or remove the alerts in `references`.
- Never show an alert past `expires`. If `expires` is missing, apply a default lifetime and label the alert "no expiry given".
- Keep Thai and English `<info>` blocks side by side; never machine-translate official text.
- Which fields TMD actually fills is unknown until real files are inspected (the feed index was read, the alert files were not). First task of the MVP: collect two weeks of TMD CAP files and document the fields.

Non-CAP sources (station readings) map to a second schema: station id, name th/en, lat, lon, value, unit, agency class, observed time, source, licence note.

### 7.3 Targeting: GPS to province, amphoe, tambon

1. Phone gets a one-shot location (existing `LocationService`) or the user picks areas by hand (the official app also offers province selection).
2. Point-in-polygon on the phone against bundled simplified COD-AB polygons gives P-codes for province, amphoe, tambon. This is pure Dart; no package needed.
3. The phone subscribes to push topics named by those codes and downloads the matching snapshot. **Coordinates never leave the phone**; only area codes do. That keeps PDPA exposure low (section 9).
4. Server matches each alert to areas by CAP `geocode` if present, else polygon intersection, else `areaDesc` name matching against a Thai/English gazetteer (last resort; log every miss).
5. The Home band shows the highest active tier for the user's tambon, then amphoe, then province, and says which level matched.

### 7.4 Push notifications and Cell Broadcast

- **Cell Broadcast (T-Alert) is the official life-safety channel.** It is sent by DDPM through operators, needs no app and no data connection, and an app cannot send, intercept or read it. This app complements it with detail, maps, local sensors and guidance. Say so in onboarding.
- App push: FCM for Android, APNs for iOS (FCM can relay to APNs). Topic per area code. Needs Firebase packages [names not verified on pub.dev this session] and a Firebase project: decision D2. Alternative without Firebase: periodic background fetch only, which is delayed and unreliable on both platforms.
- iOS **Critical Alerts** play sound through mute and Focus, and need an entitlement that Apple grants on request through a form (https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts, browser). Plan to apply; build so the app works without it.
- Android **full-screen intents**: on Android 14+ the permission is granted by default only to apps whose core function is alarms or calls; other apps must ask the user and degrade gracefully (https://support.google.com/googleplay/android-developer/answer/13392821, fetch). Use a high-importance notification channel; treat full-screen as optional.
- Notification text is the agency's headline plus area and tier word. Never a bare colour or emoji.

### 7.5 Offline caching

- Last snapshot per subscribed area, with fetch time and each alert's `expires`.
- UI states: fresh; stale (show "last updated hh:mm, d MMM", calm slate banner as DESIGN.md requires); expired (alert removed, history kept).
- Storage: `shared_preferences` is enough for a handful of small snapshots. Alert history, shelters for many provinces and tile packs need files or SQLite: decision D8. Recommend plain JSON files in the app documents directory first (no package; `dart:io`), SQLite later only if queries need it.
- Guide and shelter list stay bundled or cached, as now.

### 7.6 ESP32 pipeline

Options (decision D7):

| Option | Flow | Tradeoff |
|---|---|---|
| A. HTTPS POST | ESP32 → backend ingest endpoint | Simplest; fits the aggregator; higher power per message; no server-to-device channel |
| B. MQTT over TLS | ESP32 → broker → backend subscriber | Low overhead, retained last value, last-will for offline detection; one more service to run |
| C. Firebase Realtime Database / Firestore direct | ESP32 → Firebase → phones | Fast to demo; ties sensor data model and security rules to one vendor; device credentials are hard to rotate |
| D. LoRaWAN to a gateway | For sites without mobile coverage | Extra hardware; later phase |

Recommendation: **B for devices, feeding the same backend**, so the phone still reads one snapshot format and does not need an MQTT client. Requirements either way: per-device identity and key; signed or TLS-protected messages; device heartbeat; server-side plausibility checks (range, rate of change, stuck value); a reading is never promoted to an area alert by one sensor alone (section 10.4); community sensors are labelled "community sensor, not an official gauge" everywhere.

### 7.7 SOS delivery

Order of attempts, all user-visible:

1. **Call**: buttons for 1669 and 191 (and 1784) open the dialler. Needs a URL-launching package [not verified on pub.dev this session] or a small platform channel: decision D4. Voice works when data does not.
2. **SMS**: open the SMS composer pre-filled with coordinates, a map link and time, addressed to the user's saved contacts. The user presses send; the app does not send silently.
3. **Share sheet**: what exists today.
4. **Data** (later phase): post the SOS to the backend for a rescuer view. This needs accounts for rescuers, moderation and PDPA work; out of MVP.

Never claim that an SOS has reached rescuers unless a human or system acknowledged it. The 1.5 s hold stays.

### 7.8 Background location and battery

- MVP: **no background location**. Use the last foreground fix plus user-chosen areas. This avoids the Play foreground-service location declaration and review video (same Google page as above), the iOS "Always" prompt, and most battery cost.
- Later, if users move between areas: significant-change / low-power location only, re-subscribing topics when the amphoe changes. Decision deferred to Phase 3.
- Battery budget: no polling while the screen is off; push wakes the app; sensor screen polls only while visible; map tiles only while the map is open. Measure on a low-end Android device (section 10).

### 7.9 Every new package or service is a decision

PRODUCT.md says "No new packages" and lists Firebase, push and login as out of scope. Nothing below is added without your yes.

| Need | Without a package | With a package or service | Recommended |
|---|---|---|---|
| HTTPS fetch | `dart:io` `HttpClient` | an HTTP client package | No package |
| JSON, files | `dart:convert`, `dart:io` | — | No package |
| Localisation | hand-rolled maps | `flutter_localizations` (Flutter SDK) + `intl` + ARB | Add (D9) |
| Push | none possible | Firebase Messaging + local notifications | Add (D2) |
| Call / SMS | platform channel written by hand | URL-launcher package | Add (D4) |
| Offline tiles | bundled overview image | PMTiles / vector-tile packages | Later (D6) |
| CAP XML on phone | hand parser | XML package | Not needed if D1 = backend |
| Background work | none | background-task package | Not in MVP |
| Backend | — | hosting, object storage, CDN, scheduler, MQTT broker | Add (D1, D7) |
| Crash reporting | none | a crash-reporting SDK | Decide in Phase 0 (D12) |

Package names other than `flutter_map_tile_caching` were not checked on pub.dev this session; verify publisher, licence and maintenance before adding any.

---

## 8. Localisation

- **Thai first, English second.** Thai is the source language; English is the translation. Default locale `th`, user-switchable, independent of the phone's language.
- **Setup:** Flutter `gen-l10n` with ARB files (`app_th.arb` as template, `app_en.arb`). Move every string out of widgets, `alert_level.dart`, `location_service.dart` and `guide_data.dart`. Guide content moves as-is; its Thai text is yours to write (section 4).
- **Official text is not translated by the app.** Show the agency's Thai and English `<info>` as issued. If only Thai exists, show Thai with a label "official text, Thai only".
- **Migrant workers:** Burmese, Lao and Khmer for the fixed UI strings, tier words, SOS and Guide. Sarabun covers Thai and Latin; it will not cover Myanmar or Khmer script and may not cover Lao, so extra fonts must be bundled (font size and licence check needed). Translation must be done and reviewed by native speakers. Phase 3; decision D10.
- **Dates:** Thai locale shows the Buddhist Era (CE + 543), e.g. 12 พ.ย. 2569, as agency sites do. English shows CE. Store everything as UTC ISO 8601; display in Asia/Bangkok. Whether `intl` formats BE years for `th` by default must be tested, with an explicit unit test either way.
- **Numbers and units:** Arabic numerals; "ม." / "ซม." in Thai UI; metres above mean sea level written out in full once per screen.
- **Screen-reader wording in Thai:** write `Semantics` labels as full spoken sentences; no abbreviations (TalkBack reads "ม.รทก." letter by letter); tier word first, then area, then advice; read times as "เจ็ดนาฬิกาสามสิบนาที"-style full forms via the formatter, not "07:30 น."; test with TalkBack and VoiceOver Thai voices on real devices. Existing rule stays: every state is icon + text + colour.
- **Layout:** Thai has no spaces between words; check wrapping and the 1.5x goldens for every new string. Burmese and Khmer need taller line height than Thai; re-check `leadingDistribution` settings.

---

## 9. Legal and compliance

Not legal advice. Get Thai counsel to review before release (decision D11).

### 9.1 PDPA (Personal Data Protection Act B.E. 2562)

I could not read the Act text this session: the PDPC site (https://www.pdpc.or.th/) loaded with no readable text and the university-hosted English translation returned 403. Search results confirm unofficial English translations exist and that the PDPC is the regulator (search). Everything in this subsection is therefore **[unverified]** against the Act and is a working checklist for counsel:

| Data | Where it goes today | Planned | Checklist |
|---|---|---|---|
| Precise location | Stays on phone; shared only by the user through the share sheet | Stays on phone; only area codes sent for topic subscription | Keep it that way. State it in the privacy notice. If SOS-to-backend is built, define lawful basis, retention and access. |
| Photos in reports | Stay on phone | Stay on phone in MVP | Photos can show faces and homes. If upload is added: consent, purpose limit, retention, deletion on request. |
| Push token, area codes | — | Backend / Firebase | Pseudonymous identifiers are still personal data when linkable. Disclose; allow opt-out; cross-border transfer question if hosted outside Thailand. |
| Emergency contacts | — | On phone only | Do not upload. |
| Analytics, crash logs | None | Optional | Off by default or consented; no location in logs. |

Also needed: privacy notice in Thai and English before first permission prompt; a named data controller and contact; a way to delete all local data; a breach process; age considerations for minors.

### 9.2 Data licences

- TMD CAP feed: "public domain" per its copyright element (fetch). Still credit TMD.
- GISTDA datasets and Songkhla shelters: "Open Data Common" as labelled on their pages (fetch). The exact licence text behind that label was not read: [unverified].
- COD-AB: CC BY-IGO (browser).
- OSM: tile policy read (fetch); data licence ODbL per Protomaps footer (fetch).
- thaiwater.net API, Air4Thai JSON, DMRLIS, RID telemetry, TMD API: **no licence shown**. No production use without written permission.
- Keep a `DATA_SOURCES` page in the app listing each source, licence and last-checked date.

### 9.3 Store rules

- **Apple:** Critical Alerts entitlement by request (browser-verified page above). Expect review questions on who issues the alerts and on location use. Purpose strings must be specific.
- **Google Play:** full-screen intent and foreground-service rules as in 7.4 and 7.8 (fetch). Play also has policies for apps presenting government information and for emergency-alert claims; those pages were not read: [unverified]. Declare data safety accurately (the official app's listing shows device IDs collected).
- Do not use government emblems, the names "Thai Disaster Alert" or "T-Alert", or wording that implies endorsement.

### 9.4 Disclaimer (wording is yours; this is the required content)

Shown at first run and in About, in every supported language:

1. This app is not an official government warning channel.
2. Official warnings come from Cell Broadcast (T-Alert), DDPM, NDWC and TMD; follow them and local officials first.
3. Alerts here may be late, incomplete or wrong; no alert does not mean no danger.
4. Community sensors are not official gauges.
5. In an emergency call 1669 (medical), 191 (police) or 1784 (DDPM).

---

## 10. Testing and validation

### 10.1 Extend the existing tests

- First, resolve the diffs in `test/failures/` and re-baseline deliberately.
- `test/design_test.dart`: add every new string and screen to the overflow matrix at 1.0x, 1.3x and 1.5x, in Thai and English (then Burmese, Lao, Khmer); keep contrast assertions for all four tiers; add goldens for stale-data banner, expired alert, multi-hazard list, area picker, disclaimer, permission-priming screens.
- New unit tests: CAP parser against recorded real TMD files (Actual, Update, Cancel, Test, missing `expires`, Thai-only); tier-mapping table; point-in-polygon on boundary edges, the 102°E line, islands, and the TH1008 name fix; lat/lon axis order; BE date formatting; snapshot cache expiry.
- Semantics tests: each tier band announces word, area and advice as one label in Thai.

### 10.2 Offline drills

Scripted on real devices: airplane mode at launch; airplane mode mid-session; 2G-speed throttling; captive portal; agency source down (backend serves stale); backend down; clock set wrong. Pass rule: Home, Sensors (cached), Report, Guide and shelter list work; staleness is shown; nothing is red because of connectivity.

### 10.3 Alert latency

Measure, per alert: agency `sent` → backend ingested → push sent → push received → shown. Log all five timestamps. Targets to agree in Phase 0 (suggest median under 2 minutes from feed publication, limited mainly by poll interval). Compare against Cell Broadcast arrival during official tests. Publish the measured numbers in About; do not advertise "real time".

### 10.4 False alarms

- Only `status=Actual` reaches users; `Test` and `Exercise` are filtered and unit-tested.
- Cancels and updates are applied within one poll cycle.
- Sensor-derived alerts need two independent signals or one sensor plus an official alert for the same area; single-sensor spikes show on the Sensors screen only.
- Every alert shows source, time issued and time received.
- A "report a wrong alert" path, and a written retraction procedure including a correcting push.
- Kill switch on the backend to stop all pushes.

### 10.5 Field tests

One pilot area with a real flood history: 20 to 30 residents and local rescuers, at least a third over 60; low-end Android phones; a rainy-season period. Observe the two-second task from PRODUCT.md (find the level and SOS) one-handed, outdoors, at night. Install ESP32 sensors beside an official gauge and compare for a season before any sensor drives an alert.

### 10.6 Accessibility

1.5x text scale without clipped tone marks (goldens exist; extend); 2.0x must not lose content; TalkBack and VoiceOver in Thai; switch access and external keyboard on the SOS flow; colour-blind simulation on the four tiers; reduce-motion; 48 dp targets checked by the existing guideline test on every new screen.

### 10.7 Content review

As section 4.2. A release is blocked if any Guide row lacks reviewer sign-off or any emergency number is still "Medium" or "Low" confidence in section 3.2.

---

## 11. Phased roadmap

Effort: S = up to 2 weeks, M = 2 to 6 weeks, L = more than 6 weeks, for one developer.

### Phase 0: Decisions and permissions

| | |
|---|---|
| Deliverables | Answers to D1–D12; revised PRODUCT.md constraints (your edit); written permission requests drafted for HII, PCD, DMR, RID, GISTDA (sent only by you or with your approval); two weeks of archived TMD CAP files with a field report; official confirmation of 191, 199, 1155; counsel briefed on PDPA; goldens in `test/failures/` resolved |
| Acceptance | Every decision has an owner and a date; no "[unverified]" remains on anything the MVP depends on |
| Dependencies | You; agency response times (unknown) |
| Effort | S |
| Risks | Agencies do not reply; then the MVP ships TMD-only, which this plan already assumes |

### Phase 1: MVP — official weather warnings, localised, by area

| | |
|---|---|
| Deliverables | ARB localisation with Thai and English; four-tier alert model (if D3 says so); backend poller for TMD CAP → normalised snapshots per province; area detection on the phone from bundled province and amphoe polygons, plus manual area picker; Home band driven by real alerts with source, issue time and staleness; alert list and detail screen; call buttons for 1669 / 191 / 1784 and SMS composer in SOS; disclaimer, privacy notice and data-sources screens; push by area topic; real app id and user agent; mock sensor data kept but clearly labelled |
| Acceptance | With a recorded CAP file, the correct tier shows for a test location inside the polygon and not outside; expired alerts disappear; airplane-mode drill passes; all tests green at 1.5x in Thai and English; median push latency measured and written down; store builds pass review checklists |
| Dependencies | D1, D2, D3, D4, D9, D11; Firebase project; Apple and Google developer accounts |
| Effort | L |
| Risks | TMD CAP fields thinner than expected (areas by name only); store review pushback on alert claims; Thai copy not ready |

### Phase 2: More hazards, offline map, real shelters

| | |
|---|---|
| Deliverables | Sources added one by one as permissions arrive: PM2.5 (PCD), water level (HII / RID), landslide and flash flood (DMR), earthquakes (TMD RSS, USGS as labelled fallback), hotspots (GISTDA, FIRMS as labelled fallback), heat index; tambon-level targeting; per-province offline map packs; curated shelters for the pilot province with "last confirmed" dates; alert history; iOS Critical Alerts application |
| Acceptance | Each source has a signed permission or an explicit open licence on file; each hazard has a tier mapping approved by you; offline pack for the pilot province works with no network; shelters verified on the ground |
| Dependencies | Phase 0 permissions; D5, D6, D8 |
| Effort | L |
| Risks | Permission refused or slow; tile hosting cost; agency format changes without notice |

### Phase 3: Sensors, field pilot, more languages

| | |
|---|---|
| Deliverables | ESP32 firmware and ingest (MQTT or HTTPS); device registry and health; sensor plausibility rules; Sensors screen on real data; field pilot per 10.5; Burmese, Lao and Khmer UI; expert-reviewed Guide in all languages |
| Acceptance | One season of sensor data compared with an official gauge, error documented; pilot users complete the two-second task; zero unretracted false alerts during the pilot |
| Dependencies | D7, D10; hardware; pilot community agreement |
| Effort | L |
| Risks | Sensor drift and vandalism; connectivity at sites; translation quality |

### Phase 4: Rescue coordination (only if wanted)

| | |
|---|---|
| Deliverables | SOS and damage reports sent to a backend; rescuer view; accounts for rescuers; night theme audited to the same standard |
| Acceptance | PDPA review passed; abuse and false-SOS handling in place; acknowledged SOS is the only state shown as "received" |
| Dependencies | Legal review; a partner organisation that will actually respond |
| Effort | L |
| Risks | Creating an expectation of rescue the app cannot guarantee. This is the highest-risk feature in the plan. |

---

## 12. Open decisions for you

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Backend | (a) none, phone reads TMD CAP directly, foreground only; (b) small aggregator with static snapshots; (c) full Firebase stack | **(b)**. Needed for push, keys, outages, one data shape. **APPROVED by owner (2026-11-12), in principle.** Hosting provider, budget and PRODUCT.md edit still to be decided by you. |
| D2 | Push notifications (currently out of scope) | (a) none; (b) FCM/APNs topics by area | **(b)**. A warning app that only works when open is not a warning app. **APPROVED by owner (2026-11-12), in principle.** Adding Firebase or any package, and creating a Firebase project, each still need your separate go-ahead. |
| D3 | Fourth "Warning" tier in the data model (open item in PRODUCT.md) | (a) keep 3 in data, 4 in design; (b) 4 tiers in model and services; (c) 5 to match some agencies | **(b)**: Safe / Watch / Warning / Danger, with a per-hazard mapping table from each agency's scale that you approve. Agency's own word is always shown beside the tier. |
| D4 | SOS calling and SMS | (a) share sheet only; (b) add call and SMS-composer through a URL-launcher package; (c) hand-written platform channel | **(b)**. Smallest change that makes SOS work without data. |
| D5 | Sources without published terms (thaiwater, Air4Thai, DMRLIS, RID, TMD API) | (a) use them anyway; (b) ask each agency in writing first; (c) drop them | **(b)**; I will not contact anyone without your say-so. Until answers arrive, ship TMD CAP only. |
| D6 | Offline map | (a) online OSM only + bundled overview; (b) PMTiles province packs; (c) commercial provider; (d) GPL caching plugin | **(a) for MVP, (b) in Phase 2.** Not (d). |
| D7 | ESP32 pipeline | (a) HTTPS POST; (b) MQTT to own broker; (c) Firebase direct | **(b)**, feeding the D1 backend. |
| D8 | On-phone storage | (a) stay on `shared_preferences`; (b) JSON files via `dart:io`; (c) SQLite package | **(b)** now; (c) only if history queries demand it. |
| D9 | Thai copy and localisation (open item in PRODUCT.md) | (a) English only; (b) Thai + English ARB, Thai written by you; (c) Thai by a translator, reviewed by you | **(b)**, with expert review for safety text. Blocks MVP release. |
| D10 | Burmese, Lao, Khmer | (a) not planned; (b) Phase 3, UI and safety text; (c) MVP | **(b)**. |
| D11 | Legal review | (a) self-assessed; (b) Thai counsel reviews PDPA notice, disclaimer and store claims before release | **(b)**. |
| D12 | Crash and usage telemetry | (a) none; (b) crash reports only, no location, opt-in; (c) full analytics | **(b)**. |
| D13 | App identity | Final name, app id, publisher account | Needed before any store or tile-server work; the placeholder id must go. |
| D14 | Tsunami stance | (a) show nothing; (b) show TMD earthquake info plus a fixed pointer to T-Alert and NDWC, no tsunami tier | **(b)**. No public feed exists to do more safely. |
| D15 | Community sensor alerts | (a) sensors inform the Sensors screen only; (b) sensors can raise the area tier under the two-signal rule | **(a)** until a season of comparison data exists. |

---

## 13. Source appendix

Access date for every row: 2026-11-12. Status: **V** = page read and the stated fact seen; **P** = page reached but the fact only partly confirmed; **U** = unverified.

| # | URL | Used for | Tool | Status |
|---|---|---|---|---|
| 1 | https://www.tmd.go.th/en/api/xml/CAP | TMD CAP feed, English | fetch | V |
| 2 | https://www.tmd.go.th/api/xml/CAP | TMD CAP feed, Thai (listed in register; not fetched) | fetch (via #5) | P |
| 3 | https://data.tmd.go.th/api/index1.php | TMD API list | fetch | V |
| 4 | https://earthquake.tmd.go.th/ and /rss.html | Earthquake table, RSS list, 1182 | fetch | V |
| 5 | https://alertingauthority.wmo.int/authorities.php?recId=164 | TMD in WMO register | fetch | V |
| 6 | https://alertingauthority.wmo.int/authorities.php?recId=272 | NDWC in WMO register | fetch | V |
| 7 | https://www.disaster.go.th/home | DDPM home, 1784, links | browser | V |
| 8 | https://tdaweb.disaster.go.th/tda/AlertHome | DDPM alert web view | browser | V |
| 9 | https://ndwc.disaster.go.th/ndwc/home | NDWC notices | browser | V |
| 10 | https://thailand.prd.go.th/en/content/category/detail/id/52/iid/426007 | T-Alert launch, hazards, triggers | fetch | V |
| 11 | https://thailand.prd.go.th/en/content/category/detail/id/48/iid/466646 | Cell Broadcast nationwide test | fetch | V |
| 12 | https://www.true.th/blog/en/cell-broadcast-service/ | Five alert categories claim | search | U |
| 13 | https://www.thaiwater.net/ and /water/wl | Rain, water level, classes, API host seen | browser | V |
| 14 | https://standard.thaiwater.net/?p=6830 | Water data API standard | fetch | P |
| 15 | https://www.hii.or.th/ | HII and NHC relation | fetch | V |
| 16 | https://data.hii.or.th/ | HII data catalogue | fetch | V |
| 17 | https://www.rid.go.th/ | RID home (name only returned) | fetch | P |
| 18 | https://data.go.th/en/dataset/telerid-rid | RID telemetry dataset | fetch | V |
| 19 | wmsc.rid.go.th, swoc.rid.go.th, hotline 1460 | RID water sites | search | U |
| 20 | https://disaster.gistda.or.th/ | GISTDA Disaster Platform | browser | V |
| 21 | https://opendata.gistda.or.th/en/dataset/disasters-01 | Flood recurrence API, licence, key | fetch | V |
| 22 | https://opendata.gistda.or.th/en/dataset/disasters-02 and /disasters-04 | Drought recurrence, burnt area | search | U |
| 23 | https://www.dmr.go.th/ | DMR reports and links | fetch | V |
| 24 | https://dmrlis.dmr.go.th/ | Landslide and flash-flood levels | fetch, browser | V |
| 25 | https://dmrlis.dmr.go.th/th/api-services | DMRLIS API page (link seen, not read) | browser | P |
| 26 | http://air4thai.pcd.go.th/services/getNewAQI_JSON.php | PCD station JSON | browser | V |
| 27 | https://air4thai.pcd.go.th/webV3/#/Home | AQI levels, 1650 | browser | V |
| 28 | https://data.go.th/ (search "ภัยพิบัติ") | Open data portal | fetch | V |
| 29 | https://data.go.th/en/dataset/dpm06 | Songkhla shelters | fetch | V |
| 30 | https://www.niems.go.th/ | 1669, NIEMS | fetch | V |
| 31 | https://www.touristpolice.go.th/ | 1155 | browser | P |
| 32 | https://www.royalthaipolice.go.th/ | 191 (not shown on page) | browser | U |
| 33 | https://www.bangkokfire199.com/ | 199 (splash page only) | browser | P |
| 34 | https://www.prd.go.th/th/content/category/detail/id/9/iid/244070 | Emergency number list | search | U |
| 35 | https://www.redcross.or.th/ | Thai Red Cross, 1664 | fetch | V |
| 36 | https://www.onep.go.th/?p=112050 | Heat index levels (secondary) | fetch | V |
| 37 | Department of Health / MOPH primary heat and PM2.5 guidance | Advice source | — | U |
| 38 | ONWR (onwr.go.th) | Drought and water coordination | search | U |
| 39 | https://earthquake.usgs.gov/fdsnws/event/1/ | USGS API | fetch | V |
| 40 | https://www.gdacs.org/feed_reference.aspx | GDACS RSS feeds | fetch | V |
| 41 | https://www.gdacs.org/gdacsapi/swagger/index.html | GDACS API (did not render) | browser | U |
| 42 | https://www.tsunami.gov/?page=productRetrieval | PTWC feeds; no Indian Ocean | fetch | V |
| 43 | https://rtsp.bmkg.go.id/ and IOTWMS provider list | Indian Ocean tsunami providers | search | U |
| 44 | https://incois.gov.in/iogoos/iotws.jsp | IOTWMS description (HTTP 404) | fetch | U (down) |
| 45 | https://ahacentre.org/ | AHA Centre products | fetch | V |
| 46 | https://severeweather.wmo.int/ | WMO SWIC | fetch | V |
| 47 | "WMO Alert Hub" endpoint | CAP aggregation | — | U |
| 48 | https://firms.modaps.eosdis.nasa.gov/api/ and /api/area/ | NASA FIRMS API | fetch, browser | V |
| 49 | https://mapping.emergency.copernicus.eu/ | Copernicus EMS | fetch | V |
| 50 | https://data.humdata.org/dataset/cod-ab-tha | COD-AB Thailand | browser | V |
| 51 | DOPA admin codes | Official codes | search | U |
| 52 | Royal Thai Survey Department direct data | Boundaries | — | U |
| 53 | https://operations.osmfoundation.org/policies/tiles/ | OSM tile policy | fetch | V |
| 54 | https://docs.protomaps.com/pmtiles/ | PMTiles | fetch | V |
| 55 | https://pub.dev/packages/flutter_map_tile_caching | Plugin licence | fetch | V |
| 56 | https://www.globalfirstaidcentre.org/first-aid-guidelines-2020/ | IFRC guidelines 2020 | browser | V |
| 57 | https://www.ready.gov/be-informed | Ready.gov | fetch | V |
| 58 | WHO guidance | Advice fallback | — | U |
| 59 | https://m3.material.io/components | Material 3 | browser | V |
| 60 | https://developer.apple.com/design/human-interface-guidelines/notifications | Apple HIG | browser | V |
| 61 | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts | Critical Alerts entitlement | browser | V |
| 62 | https://support.google.com/googleplay/android-developer/answer/13392821 | Play full-screen intent and foreground service rules | fetch | V |
| 63 | https://brand.unocha.org/d/xEPytAUjC3sH/icons | OCHA icons (error page) | browser | U (down) |
| 64 | https://mobbin.com/explore/mobile/screens | Mobbin (HTTP 403) | browser | U (blocked) |
| 65 | https://dribbble.com/search/disaster-alert-app | Dribbble | browser | V |
| 66 | https://www.behance.net/search/projects?search=disaster%20alert%20app | Behance | browser | V |
| 67 | https://play.google.com/store/apps/details?id=com.THAIDAlert.DPM | THAI DISASTER ALERT | browser | V |
| 68 | https://apps.apple.com/th/app/thai-disaster-alert/id1593150344 | Thai Disaster Alert, iOS | browser | V |
| 69 | https://play.google.com/store/apps/details?id=com.depthfirst.dpm.reporter | DPM Reporter | browser | V |
| 70 | https://play.google.com/store/apps/details?id=mobile.nhc.thaiwater | ThaiWater | browser | V |
| 71 | https://play.google.com/store/apps/details?id=com.kathistudio.air4thaimobile | Air4Thai | browser | V |
| 72 | https://play.google.com/store/apps/details?id=app.android.tmd.earthquake.earthquaketmd | EarthquakeTMD - Thailand | browser | V |
| 73 | https://play.google.com/store/apps/details?id=app.nerv | NERV Disaster Prevention | browser | V |
| 74 | https://play.google.com/store/apps/details?id=jp.co.rcsc.safetyTips.android | Safety tips | browser | V |
| 75 | https://play.google.com/store/apps/details?id=gov.fema.mobile.android | FEMA | browser | V |
| 76 | https://play.google.com/store/apps/details?id=com.cube.arc.hzd | Emergency: Severe Weather App | browser | V |
| 77 | https://play.google.com/store/apps/details?id=edu.berkeley.bsl.myshake | MyShake Earthquake Alerts | browser | V |
| 78 | https://www.pdpc.or.th/ | PDPC (page loaded, no text) | browser | U |
| 79 | https://muit.mahidol.ac.th/downloads/act-policy/2_Personal-Data-Protection-Act-2019-en.pdf | PDPA unofficial English text (HTTP 403) | fetch | U (blocked) |
| 80 | BMA flood and drainage data | Urban flood | — | U |

**Totals:** 80 source rows. V = 55, P = 6, U = 19.

**Down, blocked or behind a login**

- Down or erroring: INCOIS IOTWMS page (404); OCHA icons page (error); GDACS Swagger (blank); PDPC home (no text rendered).
- Blocked: Mobbin (403); Mahidol PDPA PDF (403); HDX and Air4Thai failed in plain fetch (403, certificate) but were read in the browser.
- Key or registration needed, not obtained: GISTDA API Gateway; NASA FIRMS `MAP_KEY`; TMD NWP forecast API.
- Sign-in link present but public content read: GISTDA Disaster Platform, HII data catalogue.

---

## 14. Follow-up research (2026-11-12, built-in browser and fetch; agent-browser CLI not installed)

**TMD CAP file fields** (fetch of https://www.tmd.go.th/uploads/CAP/en/CAPTMD20261112062845_2.xml, "Heavy Rain", read as static XML):

| Field | Seen |
|---|---|
| identifier, sender, sent, status, msgType, scope | present (`TMD20261112062845_2-en`, `TMD`, +07:00 time, `Actual`, `Alert`, `Public`) |
| references | absent (an original alert, not an update) |
| info: language, category, event, urgency, severity, certainty | present (`en-US`, `Met`, `Heavy Rain`, `Expected`, `Severe`, `Likely`) |
| info: effective, expires | present, +07:00 offsets; 12 h window |
| info: onset | absent |
| info: headline, description, instruction, web | present, English only in this file |
| area: areaDesc | present, province names in one string |
| area: polygon | present, about 115 polygons |
| area: geocode | present, ISO 3166-2 province codes (TH-81 ... TH-96, 11 values) |

Consequences: targeting can use province-level `geocode` first, polygons second. Timestamps carry +07:00, so parse offsets and store UTC. Each alert is a separate file per language (`/en/`, the Thai folder was not fetched). Only one file was read, so Update, Cancel, Test and Thai-only cases are still unseen. Feed index lists 8 items, 9 to 12 Nov 2026.

**Emergency numbers 191, 199, 1155:** still **not confirmed on an official page**. The PRD page cited in 3.2 now returns HTTP 404; the Royal Thai Police home page shows no numbers. A search summary says a Ministry of Tourism and Sports handbook PDF (https://province.mots.go.th/ewtadmin/ewt/phetchaburi/download/HandbookEnterpreneur.pdf) lists 191, 199, 1155; I did not open it. Confidence stays Medium. The release block in 10.7 stands.
