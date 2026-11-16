# Water-level node (Arduino scale)

One ESP32 + one ultrasonic sensor + a small Python server. Small, but it has the parts that matter:
checked readings, signed uplink, offline buffer, local alarm, and "unknown, never safe".

```
ESP32 + JSN-SR04T --signed HTTP POST--> backend/sensor_ingest.py --GET /snapshot--> app
```

Status: the server and simulator are tested (`backend/test_ingest.py`, 18 tests). The firmware has
**not been compiled or run on hardware** (no `arduino-cli` here). The watchdog call is the least
verified part; it is guarded for core 2.x and 3.x.

## Parts (about 300-600 baht)
ESP32 dev board, JSN-SR04T waterproof ultrasonic sensor (HC-SR04 for a bucket test only), an
active buzzer (optional), 1 kΩ + 2 kΩ resistors, jumper wires, USB power.

## Wiring
| Sensor | ESP32 |
|---|---|
| VCC | 5V (VIN) |
| GND | GND |
| TRIG | GPIO 5 |
| ECHO | GPIO 18 **through a divider**: 1 kΩ in series, then 2 kΩ from that point to GND; GPIO reads the junction |
| Buzzer + | GPIO 4 (active buzzer) |
| LED | built-in, GPIO 2 |

The sensor's ECHO is 5 V; the ESP32 pins tolerate 3.3 V. Without the divider you can damage the board.

## Setup
1. Arduino IDE + board package "esp32 by Espressif".
2. In `water_sensor/`: copy `secrets.example.h` to `secrets.h`, fill in Wi-Fi, `SERVER_URL`, and a key
   (`python -c "import secrets; print(secrets.token_hex(32))"`).
3. In `config.h`: set `SENSOR_HEIGHT_CM` (sensor face to the zero mark). The build refuses a Danger
   level the sensor cannot read (it cannot measure closer than 25 cm).
4. In `backend/`: copy `stations.example.json` to `stations.json`, same key and same heights/levels.
5. Run the server: `python sensor_ingest.py` (listens on port 8080; LAN only, no TLS).
6. Upload the sketch. The Serial Monitor (115200) shows readings and the IP. `http://<ip>/reading` shows local state.
7. No hardware yet? `python simulate.py --key <key> --scenario flood`, then open `http://127.0.0.1:8080/snapshot`.

## What it does
- **Reading:** median of 5 pings every 30 s; every 5 s while water is at Watch or higher or a reading is in doubt.
- **Checks (device and server):** valid range, big jump (needs a confirming second reading), stuck value, rate of change.
- **Rise rate:** cm/h over 10 min. Rising 20 cm/h or more counts as at least Watch.
- **Local alarm:** LED/buzzer by band; Danger is solid LED plus a beeping buzzer. Fault shows a double blip (unknown).
- **Uplink:** each reading is a signed POST (HMAC-SHA256, per-device key, rising counter). The server
  rejects bad signatures (401) and replays (409). Times are sent as "age" (ms ago), so no clock is needed.
- **Offline:** up to 256 readings are buffered in RAM and sent newest first when the link returns.
  A reboot loses the buffer. The counter is saved to flash once per 100 messages.
- **Server:** recomputes the level from the raw distance, and reports `stale` after 2 min and `offline` after 10 min.
  **Anything not `ok` is band `unknown`.** It never says safe when it cannot see the water.

## What it deliberately does not do
- **No area alerts.** A sensor reading is an observation, labelled "Community sensor, not an official
  gauge". It never issues an official warning or evacuation order (plan D15; legal review pending).
- **No deep sleep, battery or solar, 4G, or TLS in this version.** Deep sleep conflicts with the
  local web page and Wi-Fi state; add power management once the rest is proven. For anything outside a
  LAN, put a TLS reverse proxy in front of the server.
- **No vibration sensing.** Thresholds that are safe for landslide or earthquake need field data.
- **Uplink is HTTP POST, not MQTT** (a difference from decision D7(b) in the development plan). No broker
  to run; same signed payload can move to MQTT later.

## Tune in the field
`STUCK_N` (still water can read very steady), `MAX_JUMP_CM`, band levels, and the intervals.
Compare against an official gauge for a season before trusting any threshold.
