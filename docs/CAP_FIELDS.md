# TMD CAP feed: what TMD actually fills

Captured 2026-11-18 (one day of capture, not two weeks) with `backend/capture_cap.py`
from the live feeds. Fixtures are real, unmodified files in `backend/fixtures/cap/`, stored as raw bytes
(BOM and CRLF kept) via `backend/fixtures/cap/** -text` in `.gitattributes`.
The feed's copyright element says "public domain".

## Feeds

| Feed | URL | Files link into |
|---|---|---|
| English | `https://www.tmd.go.th/en/api/xml/CAP` | `https://www.tmd.go.th/uploads/CAP/en/<name>.xml` |
| Thai | `https://www.tmd.go.th/api/xml/CAP` | `https://www.tmd.go.th/uploads/CAP/<name>.xml` |
| `/th/api/xml/CAP` | HTTP 500 (do not use) | |

Both answer HTTP 200 with RSS 2.0 and list the **same 6 alerts** (the feed shows only the
last ~3 days). `feed_links()` returns 6 URLs for each. The RSS `<item>` has title, link,
description, author, pubDate, guid. English guid is `TMD<ts>_2-en`; Thai guid is `TMD<ts>_2`.
The two feeds' channel `pubDate` differed (en 16:45, th 10:45 on the same moment), so the
Thai index can lag the English one. Poll both or prefer English.

## Thai versus English files

- Same file name `CAPTMD<yyyymmddHHMMSS>_2.xml`, in the `/en/` folder or the parent folder.
- `identifier`: English = Thai + `-en` suffix (`TMD20261117053453_2` / `TMD20261117053453_2-en`).
  So the identifier minus a trailing `-en` links the pair.
- `info/language`: `en-US` versus `th-TH`. Same single `<info>` block in each.
- Identical: sent, status, msgType, scope, category, event (still English text "Heavy Rain"
  in the Thai file), urgency, severity, certainty, effective, expires, polygons, geocodes,
  `web` (the Thai file's `web` still points to the `/en/forecast/daily` page).
- Translated: headline, description, instruction, areaDesc (province names in Thai).
- Thai-only files: **not seen**. Every Thai file had an English twin.

## Fields seen (12 files: 6 en, 6 th, all CAP 1.2, ns `urn:oasis:names:tc:emergency:cap:1.2`)

| Field | Filled? | Observed values / notes |
|---|---|---|
| identifier | always | `TMD<ts>_2` (+`-en`) |
| sender | always | `TMD` |
| sent | always | `+07:00` offset, minute precision, e.g. `2026-11-17T05:29:00+07:00` |
| status | always | `Actual` only |
| msgType | always | `Alert` (5 files), `Update` (1 file: 20261116051107) |
| scope | always | `Public` |
| references | only on the Update | `TMD,TMD20261115160447_2,2026-11-15T16:02:00+07:00` (`sender,identifier,sent`). The referenced identifier uses the Thai form with no `-en`, even in the English file, and that older alert is not in the feed or fixtures |
| info count | always 1 | one `<info>` per file, one language per file |
| category | always | `Met` |
| event | always | `Heavy Rain` only |
| urgency / severity / certainty | always | `Immediate` / `Severe` / `Likely` in all 12 |
| responseType | never | absent |
| effective | always | can be later than `sent` (alert sent 15:52 effective 18:00) |
| onset | never | absent |
| expires | always (in 12 of 12) | `+07:00`; a file without `expires` was **not seen** |
| senderName | always | `TMD` |
| headline | always | e.g. `Heavy Rain Risk Area` |
| description / instruction | always | long free text, contains CRLF and newlines |
| web | always | `https://www.tmd.go.th/en/forecast/daily` |
| parameter, resource, contact | never | absent |
| area | always 1 | one `<area>` per file |
| areaDesc | always | space-separated province names (not comma separated) |
| polygon | always | 10 to 68 per file (en: 68, 44, 10, 17, 17, 36); `lat,lon` pairs separated by spaces, closed rings (first = last), min 4 points. Multi-polygon: one `<polygon>` element each |
| geocode | always | `valueName` = `ISO3166-2`, `value` = `TH-NN` province code, one `<geocode>` per province (4 to 9 per file; seen TH-80, 84, 90..96). Carried in the snapshot as `areaCodes` (sorted, de-duplicated; only `ISO3166-2` + `TH-` and two ASCII digits, anything else skipped); the snapshot's `noArea` counts alerts with neither polygons nor codes |
| Signature | always | XML-DSig enveloped RSA-SHA256, in namespace `http://www.w3.org/2000/09/xmldsig#`, after `</info>`. Not verified by us |

## Encoding and shape quirks for the parser

- All 12 files start with a UTF-8 BOM (`EF BB BF`) and use CRLF line endings. Read as bytes
  (`ET.fromstring(bytes)`) or decode `utf-8-sig`; `ET.fromstring(str)` with a leading BOM
  may fail. The Thai text is valid UTF-8 (only a Windows console shows it garbled).
- The RSS feed itself had no BOM.
- Sizes 42 to 70 KB each (polygons dominate).
- `<alert>` has a default namespace, so tag lookups need the CAP 1.2 namespace.

## Kinds seen and NOT seen (honest list)

| Kind | Seen? | Fixture |
|---|---|---|
| Actual / Alert, English | yes (5) | `en_CAPTMD20261116155515_2.xml` etc. |
| Actual / Update, English | yes (1) | `en_CAPTMD20261116051107_2.xml` (has `references`) |
| Thai twin of the above | yes (6) | `th_*.xml` |
| Cancel | **not seen** | none |
| Test (status `Test`) | **not seen** | none |
| Thai-only (no English twin) | **not seen** | none |
| Missing `expires` | **not seen** | none |
| Missing polygon (geocode only) | **not seen** | none |
| Other events (storm, flood, cold, ...), other severities | **not seen** | none; every file is `Heavy Rain` / `Severe` |
| Multiple `<info>` or multiple `<area>` | **not seen** | none |

The unseen kinds are covered by hand-written synthetic files (next section), not by real data.

## Synthetic fixtures

`backend/fixtures/cap/synthetic/synthetic_*.xml` are **invented** (Task 2) to cover shapes
TMD has not yet been seen to publish. Each carries an XML comment saying so. They are small,
unsigned, LF-only, and must never be read as evidence of what TMD sends.

| File | Covers |
|---|---|
| `synthetic_cancel_no_info.xml` | `msgType` Cancel with `references` and no `<info>` (legal in CAP 1.2) |
| `synthetic_test_status.xml` | `status` Test, severity Minor |
| `synthetic_no_expires.xml` | no `<expires>`, severity Extreme, event Storm |
| `synthetic_bad_expires.xml` | unparseable `<expires>` text |
| `synthetic_geocode_only.xml` | `<area>` with geocodes and no `<polygon>` |
| `synthetic_multi_info.xml` | 3 `<info>` (en/th/en, Moderate/Extreme/Minor), 2 `<area>`, duplicate ring, 2-point ring, ring with a non-number, a malformed reference triple |

Replace each with a real capture once TMD publishes that kind.

## Closing the DEVELOPMENT_PLAN section 7.2 `[unverified]`

Verified: polygons and ISO 3166-2 province geocodes are both present in every real file,
times carry `+07:00`, and the Update/`references` shape is as above. Still unverified:
Cancel, Test, missing `expires`, missing polygon, non-rain events.

## Fixture files

`backend/fixtures/cap/`: `feed_en.rss.xml`, `feed_th.rss.xml` (RSS indexes),
`en_CAPTMD*.xml` (6), `th_CAPTMD*.xml` (6). The `en_`/`th_` prefix was added when copying;
the capture script writes the original name, which is identical in both feeds.
