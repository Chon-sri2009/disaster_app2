#pragma once
// Tunables for one water-level node. Nothing secret here (see secrets.h).
// The server keeps its own copy of the thresholds in backend/stations.json and
// is the authority for the alert band; the values here drive the LOCAL alarm
// and the reporting speed only.
#include <Arduino.h>

#define STATION_ID "station-1"

// Pins. Echo of a 5 V sensor needs a voltage divider (see firmware/README.md).
#define TRIG_PIN 5
#define ECHO_PIN 18
#define LED_PIN 2
#define BUZZER_PIN 4  // ACTIVE buzzer, HIGH = on. Set to -1 for none.

// Distance (cm) from the sensor face down to the zero mark (riverbed or
// normal level). Measure once after mounting.
constexpr float SENSOR_HEIGHT_CM = 300.0;

// Sensor limits (JSN-SR04T has a ~25 cm blind zone and ~450 cm range).
constexpr float MIN_VALID_CM = 25.0;
constexpr float MAX_VALID_CM = 450.0;
constexpr int SAMPLES = 5;  // pings per reading, median taken

// Plausibility.
constexpr float MAX_JUMP_CM = 30.0;  // larger step must be confirmed by next reading
constexpr int STUCK_N = 90;          // this many ~identical readings in a row = fault
constexpr float STUCK_EPS_CM = 0.1;

// Local alarm bands: water level in cm above zero.
constexpr float WATCH_CM = 120.0;
constexpr float WARNING_CM = 160.0;
constexpr float DANGER_CM = 185.0;
constexpr float RISE_WATCH_CM_H = 20.0;  // rising this fast is at least Watch

// The sensor cannot read closer than MIN_VALID_CM, so the top band must fit below it.
static_assert(DANGER_CM <= SENSOR_HEIGHT_CM - MIN_VALID_CM,
              "Danger level is above what the sensor can measure: mount it higher or lower DANGER_CM");

// Timing. Faster reporting while the water is high or a reading is in doubt.
constexpr uint32_t NORMAL_INTERVAL_MS = 30000;
constexpr uint32_t FAST_INTERVAL_MS = 5000;
constexpr uint32_t RATE_WINDOW_MS = 600000;    // rise rate over the last 10 min
constexpr uint32_t RATE_MIN_SPAN_MS = 120000;  // need at least 2 min of data

// Uplink.
constexpr size_t BUFFER_SIZE = 256;       // unsent readings kept in RAM
constexpr int MAX_SEND_PER_LOOP = 5;
constexpr uint32_t POST_TIMEOUT_MS = 4000;
constexpr uint32_t RETRY_MS = 5000;
constexpr uint32_t WIFI_RETRY_MS = 30000;
constexpr uint32_t SEQ_SKIP = 100;        // message counter saved to flash once per this many

constexpr uint32_t WDT_TIMEOUT_S = 60;
