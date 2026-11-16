#pragma once
// Copy this file to secrets.h and fill it in. Never share or commit secrets.h.

#define WIFI_SSID "YOUR_WIFI_OR_PHONE_HOTSPOT"
#define WIFI_PASS "YOUR_PASSWORD"

// Where the ingest server (backend/sensor_ingest.py) runs.
#define SERVER_URL "http://192.168.1.50:8080/ingest"

// Per-device secret. Make one per station:
//   python -c "import secrets; print(secrets.token_hex(32))"
// The same string goes in backend/stations.json under this station's id.
#define DEVICE_KEY "PUT_A_64_CHARACTER_RANDOM_STRING_HERE"

// Only if SERVER_URL starts with https://, paste the server's root CA (PEM):
// #define SERVER_ROOT_CA "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
