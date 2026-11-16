# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Residents of flood- and earthquake-prone areas, and rescuers. Often scared, outdoors at night or in rain, using one hand, on low battery and a weak or absent signal. Thai is the primary language, English secondary. Some are elderly or have low vision. (Source: the user's brief, confirmed; no interview round was run, the brief answered it.)

## Product Purpose

"Disaster Alert & Rescue" covers before, during and after a disaster in one app: an area alert level, live sensor readings (water level, vibration), a one-action SOS that shares GPS coordinates, shelter map, damage reports saved on the phone, and an offline first-aid and evacuation guide. Success is a frightened person finding the alert level and the SOS control in under two seconds, with no signal.

## Positioning

Built to keep working offline: the Home, Sensors, Report and Guide screens and the shelter list need no internet. Low-cost ESP32 sensors (water level, vibration) will later feed the app; today all sensor and alert data is mock data.

## Operating Context

Registers: product (Operate mode). Portrait first, one-handed use. Sensor and alert data is mock data in `lib/data/mock_data.dart` until ESP32/Firebase is connected. Map tiles come from OpenStreetMap and are blank offline.

## Capabilities and Constraints

- Flutter, Dart 3, Material 3. Packages: flutter_map, latlong2, geolocator, image_picker, share_plus, shared_preferences. No new packages.
- State with ChangeNotifier and ListenableBuilder only.
- Out of scope: login, push notifications, Firebase, dark-mode switching.
- Safety and first-aid wording is content owned by the user: not reworded without asking.
- Open product decision: a fourth alert level, "Warning", is requested by design but the data model and sensor service only emit Safe / Watch / Danger.
- Open product decision: Thai translations of all copy do not exist yet.

## Product Principles

1. Glanceable before beautiful: the alert level and SOS are readable and reachable in two seconds.
2. Never rely on color alone: every state has a distinct icon and a text label.
3. Offline is a normal state, never an alarm.
4. A dangerous action needs deliberate confirmation (press and hold), not a stray tap.
5. Say what is mock or stale: never imply a live reading that is not.

## Accessibility & Inclusion

Targets: text contrast 4.5:1, UI components 3:1, tap targets at least 48 dp, body text at least 16 sp, works at 1.5x text scale without clipping Thai diacritics, screen-reader labels on every control, reduce-motion respected.
