# Disaster Alert & Rescue

A Thai-first Flutter app for floods and earthquakes: an alert level, an offline shelter map,
a press-and-hold SOS that shares your GPS position, damage reports saved on the phone, and an
offline first-aid guide. Community ESP32 water sensors feed it through a small backend.

The app reports observations. It never issues official evacuation orders. See
[PRODUCT.md](PRODUCT.md) for the rules the UI follows (say what is demo or stale, never show a
false Safe, offline is a normal state) and [docs/OWNER_TODO.md](docs/OWNER_TODO.md) for what is
still needed before a release.

## Run the app

```bash
flutter pub get
flutter run
```

Debug builds with no server show clearly labelled demo data. Release builds with no server show
"No live data". To read real sensors, point the app at the backend:

```bash
flutter run --dart-define=SENSOR_SNAPSHOT_URL=https://your-host/snapshot
```

## Test

```bash
flutter analyze
flutter test
cd backend && python -m unittest test_ingest
```

Golden screenshots in `test/goldens/` are rewritten by `flutter test`; review them in the diff.

## Parts

| Folder | What it is |
| --- | --- |
| `lib/` | The Flutter app |
| `backend/` | Python (standard library only) server: signed `/ingest`, `/snapshot`, `/health`. Put a TLS proxy in front of it |
| `firmware/` | ESP32 water-level sensor, see [firmware/README.md](firmware/README.md) |
| `docs/` | Plans, audits and owner checklists |

App id: `app.disasteralert.th` (a placeholder until you own a domain; change it before the first
store upload, since it cannot change afterwards).
