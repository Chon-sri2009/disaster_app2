# Owner to-do list

Things only you (the owner) can do or decide. Tick them off as you go.
Written 2026-11-13. Prices and links were checked on that date; check them again before budgeting.

## 1. Switch the map to Protomaps (offline maps)

- [ ] Download the `pmtiles` tool: GitHub → protomaps/go-pmtiles → Releases → the `Windows_x86_64` zip. Unzip `pmtiles.exe` into a folder such as `D:\Disaster_APP\tools\`.
- [ ] Find a recent world map date in Protomaps' builds list (files are named like `20261002.pmtiles` on `build.protomaps.com`).
- [ ] Check the area's edges (west, south, east, north) at bboxfinder.com. The edges below are approximate.
- [ ] Cut a small test file first (Bangkok):
  ```
  pmtiles extract https://build.protomaps.com/20261002.pmtiles bangkok.pmtiles --bbox=100.33,13.49,100.94,13.96
  ```
- [ ] If it works, cut the pilot province or all of Thailand:
  ```
  pmtiles extract https://build.protomaps.com/20261002.pmtiles thailand.pmtiles --bbox=97.34,5.61,105.64,20.46
  ```
  Add `--maxzoom=14` if the file is too big. For an exact province border, use `--region=province.geojson` instead of `--bbox`.
- [ ] Open the file in Protomaps' online viewer (maps.protomaps.com) to check it, and note the file size.
- [ ] Decide: is the pilot province's map built into the app, or do users download provinces themselves?
- [ ] Later, before release: create a Cloudflare account and one R2 storage bucket to host the map file. R2 is about $0.015 per GB a month, the first 10 GB are free, and downloads are free. You keep the login yourself.
- [ ] Say yes or no to a throwaway test from Claude: one province file on the map, to check that Thai labels display correctly and that older phones are fast enough.

## 2. Decisions from the brainstorming

- [ ] **Pilot area:** a city (sois and underpasses, like Bangkok) or a rural area near a river?
- [ ] **Pilot size:** a few hundred, a few thousand, or a whole province? This sets the hosting and SMS cost.
- [ ] **Routing:** show flooded streets only, or also give a route around them? A route needs a small extra server (Valhalla).
- [ ] **Live traffic in the app:** needed or not? Only Google and other paid providers have it.
- [ ] **Alert texts (SMS):** who pays: the project, a partner (a mobile network or the province), or the users? A Thai alert is usually 2 SMS segments at about ฿0.15–1 each.
- [ ] **Who must be reached without a smartphone:** older people, farmers out in the fields, tourists?
- [ ] **What kind of outage:** in the pilot area during floods, is it slow or no mobile data, or does the whole phone network go down?

## 3. Checks for a lawyer or official contacts

- [ ] Ask your lawyer who is allowed to issue disaster warnings in Thailand, and whether "observation, not an official warning" wording is enough for our sensor and community alerts.
- [ ] Check the terms of Waze's partner programme for cities and organisations, so we can feed our flood points to Waze and Google Maps.
- [ ] Confirm prior art: Bangkok's own flood sensors, Traffy Fondue, and T-Alert's delays in past events.
- [ ] If SMS is used, ask the SMS provider about sender-name registration in Thailand.

## 4. Still open from earlier

- [ ] Fill in `docs/INPUTS_NEEDED.md` or `docs/INPUTS_NEEDED.pdf`: alert-tier mapping, hosting, app name, Thai text, Firebase, agency permissions, the sources for 191, 199 and 1155, a lawyer, reviewers.
- [ ] Go-ahead for the alert layer on the map.
- [ ] Share the overview document and the slides from each one's Share menu before the meeting.
