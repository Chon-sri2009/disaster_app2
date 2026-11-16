// Water-level node, small but complete: ESP32 + ultrasonic sensor.
//
//  - median-of-5 reading with range, jump and stuck-value checks
//  - rise rate (cm/h) and a local alarm (LED + optional buzzer)
//  - signed HTTP POST of every reading to the ingest server (HMAC-SHA256,
//    per-device key, increasing message counter)
//  - RAM buffer for readings while Wi-Fi/server is down; newest sent first
//  - reports faster when water is high or a reading is in doubt
//  - hardware watchdog, Wi-Fi retry, local JSON at http://<ip>/reading
//
// A fault or missing echo is "unknown", never "safe".
// Only libraries built into the ESP32 Arduino core are used.

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <Preferences.h>
#include <esp_task_wdt.h>
#include "mbedtls/md.h"

#include "config.h"
#include "secrets.h"  // copy secrets.example.h to secrets.h

enum Fault : uint8_t { F_OK = 0, F_NOECHO, F_RANGE, F_JUMP, F_STUCK };
const char* const FAULT_NAME[] = {"ok", "noecho", "range", "jump", "stuck"};
enum Band : uint8_t { B_UNKNOWN = 0, B_SAFE, B_WATCH, B_WARNING, B_DANGER };
const char* const BAND_NAME[] = {"unknown", "safe", "watch", "warning", "danger"};

struct Sample {
  uint32_t ms;  // millis() when taken
  float dist;   // NAN when there was no usable echo
  uint8_t fault;
};

// ---------------------------------------------------------------- state
Sample ring[BUFFER_SIZE];  // unsent readings; head = next write slot
size_t ringHead = 0, ringCount = 0;

struct RatePt { uint32_t ms; float water; };
RatePt ratePts[128];
size_t rateHead = 0, rateCount = 0;

Band curBand = B_UNKNOWN;
Fault curFault = F_NOECHO;
float curWater = NAN, curRise = NAN, curDist = NAN;
uint32_t lastSampleMs = 0;
bool haveSample = false;

bool havePrev = false, jumpPending = false;
float prevDist = 0, pendDist = 0;
float stuckRef = -1000;
int stuckCount = 0;

uint32_t nextSampleMs = 0, nextFlushMs = 0, nextWifiTryMs = 0;

Preferences prefs;
uint32_t seq = 0;
WebServer server(80);

// ----------------------------------------------------------- buffer
void bufPush(const Sample& s) {
  ring[ringHead] = s;
  ringHead = (ringHead + 1) % BUFFER_SIZE;
  if (ringCount < BUFFER_SIZE) ringCount++;  // full: oldest is overwritten
}
Sample* bufNewest() {
  return ringCount ? &ring[(ringHead + BUFFER_SIZE - 1) % BUFFER_SIZE] : nullptr;
}
void bufDropNewest() {
  if (!ringCount) return;
  ringHead = (ringHead + BUFFER_SIZE - 1) % BUFFER_SIZE;
  ringCount--;
}

// ------------------------------------------------------ measurement
float pingCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, 30000);
  if (us == 0) return NAN;
  return us * 0.0343f / 2.0f;  // speed of sound ~343 m/s
}

// Median of SAMPLES pings. Needs at least 3 valid pings to agree.
Fault measure(float& out) {
  float v[SAMPLES];
  int n = 0, noEcho = 0, outOfRange = 0;
  for (int i = 0; i < SAMPLES; i++) {
    float d = pingCm();
    if (isnan(d)) noEcho++;
    else if (d < MIN_VALID_CM || d > MAX_VALID_CM) outOfRange++;
    else v[n++] = d;
    delay(60);
  }
  out = NAN;
  if (n < 3) return noEcho >= outOfRange ? F_NOECHO : F_RANGE;
  for (int i = 1; i < n; i++) {
    float x = v[i];
    int j = i - 1;
    while (j >= 0 && v[j] > x) { v[j + 1] = v[j]; j--; }
    v[j + 1] = x;
  }
  out = v[n / 2];
  return F_OK;
}

// A step bigger than MAX_JUMP_CM is accepted only if the next reading agrees.
Fault checkJump(float d) {
  if (!havePrev) { havePrev = true; prevDist = d; return F_OK; }
  if (fabsf(d - prevDist) <= MAX_JUMP_CM) { prevDist = d; jumpPending = false; return F_OK; }
  if (jumpPending && fabsf(d - pendDist) <= MAX_JUMP_CM) {
    prevDist = d; jumpPending = false; return F_OK;
  }
  jumpPending = true;
  pendDist = d;
  return F_JUMP;
}

// STUCK_N readings within STUCK_EPS_CM of each other: sensor is probably stuck.
// Tune STUCK_N in the field: still water can legitimately read very steady.
Fault checkStuck(float d) {
  if (fabsf(d - stuckRef) <= STUCK_EPS_CM) stuckCount++;
  else { stuckRef = d; stuckCount = 1; }
  return stuckCount >= STUCK_N ? F_STUCK : F_OK;
}

// ------------------------------------------------------- rise rate
void ratePush(uint32_t ms, float water) {
  ratePts[rateHead] = {ms, water};
  rateHead = (rateHead + 1) % 128;
  if (rateCount < 128) rateCount++;
}

// cm per hour over the last RATE_WINDOW_MS, or NAN if less than RATE_MIN_SPAN_MS of data.
float computeRise() {
  if (!rateCount) return NAN;
  RatePt newest = ratePts[(rateHead + 127) % 128];
  RatePt oldest = newest;
  for (size_t i = 1; i < rateCount; i++) {
    RatePt p = ratePts[(rateHead + 128 - 1 - i) % 128];
    if (newest.ms - p.ms > RATE_WINDOW_MS) break;
    oldest = p;
  }
  uint32_t span = newest.ms - oldest.ms;
  if (span < RATE_MIN_SPAN_MS) return NAN;
  return (newest.water - oldest.water) / (span / 3600000.0f);
}

Band bandFor(float water, float rise) {
  Band b = water >= DANGER_CM ? B_DANGER
         : water >= WARNING_CM ? B_WARNING
         : water >= WATCH_CM ? B_WATCH : B_SAFE;
  if (!isnan(rise) && rise >= RISE_WATCH_CM_H && b < B_WATCH) b = B_WATCH;
  return b;
}

// ----------------------------------------------------------- sample
void takeSample() {
  uint32_t ms = millis();
  float d;
  Fault f = measure(d);
  if (f == F_OK) f = checkJump(d);
  if (f == F_OK) f = checkStuck(d);

  curFault = f;
  lastSampleMs = ms;
  haveSample = true;
  if (f == F_OK) {
    curDist = d;
    curWater = SENSOR_HEIGHT_CM - d;
    ratePush(ms, curWater);
    curRise = computeRise();
    curBand = bandFor(curWater, curRise);
    Serial.printf("dist %.1f cm  water %.1f cm  rise %.1f cm/h  %s\n", d, curWater,
                  isnan(curRise) ? 0.0f : curRise, BAND_NAME[curBand]);
  } else {
    curDist = NAN;
    curWater = NAN;
    curRise = NAN;
    curBand = B_UNKNOWN;  // never "safe" when we cannot trust the reading
    Serial.printf("fault: %s\n", FAULT_NAME[f]);
  }
  bufPush({ms, (f == F_NOECHO || f == F_RANGE) ? NAN : d, (uint8_t)f});
  nextFlushMs = millis();  // due now (never 0: see the signed-compare note in loop())
}

uint32_t intervalNow() {
  bool urgent = curBand >= B_WATCH || curFault == F_JUMP;
  return urgent ? FAST_INTERVAL_MS : NORMAL_INTERVAL_MS;
}

// ------------------------------------------------------------ uplink
String hmacHex(const char* body, size_t len) {
  uint8_t out[32];
  mbedtls_md_hmac(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256),
                  (const uint8_t*)DEVICE_KEY, strlen(DEVICE_KEY),
                  (const uint8_t*)body, len, out);
  char hex[65];
  for (int i = 0; i < 32; i++) sprintf(hex + 2 * i, "%02x", out[i]);
  return String(hex);
}

void initSeq() {
  prefs.begin("node", false);
  seq = prefs.getUInt("seq", 0) + SEQ_SKIP;  // jump ahead of anything sent before a reboot
  prefs.putUInt("seq", seq);
}
uint32_t nextSeq() {
  seq++;
  if (seq % SEQ_SKIP == 0) prefs.putUInt("seq", seq);  // one flash write per SEQ_SKIP messages
  return seq;
}

// true = delivered, or rejected for good (drop it); false = try again later.
bool postSample(const Sample& s) {
  if (WiFi.status() != WL_CONNECTED) return false;

  char dist[16];
  if (isnan(s.dist)) snprintf(dist, sizeof dist, "null");
  else snprintf(dist, sizeof dist, "%.1f", s.dist);
  char body[200];
  int n = snprintf(body, sizeof body,
                   "{\"id\":\"%s\",\"seq\":%lu,\"ageMs\":%lu,\"dist\":%s,\"fault\":\"%s\","
                   "\"rssi\":%d}",
                   STATION_ID, (unsigned long)nextSeq(), (unsigned long)(millis() - s.ms),
                   dist, FAULT_NAME[s.fault], WiFi.RSSI());

#ifdef SERVER_ROOT_CA
  WiFiClientSecure client;
  client.setCACert(SERVER_ROOT_CA);
#else
  WiFiClient client;
#endif
  HTTPClient http;
  if (!http.begin(client, SERVER_URL)) return false;
  http.setConnectTimeout(POST_TIMEOUT_MS);
  http.setTimeout(POST_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device", STATION_ID);
  http.addHeader("X-Signature", hmacHex(body, n));
  int code = http.POST(String(body));

  bool done = false;
  if (code == 200) {
    done = true;
  } else if (code == 409) {
    // Server has seen a higher counter (e.g. flash was erased). Catch up and retry.
    String r = http.getString();
    int i = r.indexOf("\"lastSeq\":");
    if (i >= 0) {
      uint32_t last = (uint32_t)r.substring(i + 10).toInt();
      if (last > seq && last < seq + 1000000UL) {
        seq = last;
        prefs.putUInt("seq", seq);
      }
    }
  } else if (code == 400 || code == 401 || code == 413) {
    Serial.printf("server rejected reading (HTTP %d), dropping it\n", code);
    done = true;  // retrying the same thing will never work
  } else {
    Serial.printf("post failed (%d)\n", code);
  }
  http.end();
  return done;
}

// Newest first, so after an outage the current level is not stuck behind old data.
// Returns false only when a send failed (back off); true if it emptied the buffer
// or hit the per-loop cap (carry on at once).
bool flushBuffer() {
  for (int i = 0; i < MAX_SEND_PER_LOOP && ringCount; i++) {
    esp_task_wdt_reset();
    if (!postSample(*bufNewest())) return false;
    bufDropNewest();
  }
  return true;
}

// -------------------------------------------------------- local alarm
void updateAlarm() {
  uint32_t t = millis();
  bool led = false, buz = false;
  switch (curBand) {
    case B_SAFE: led = (t % 5000) < 80; break;
    case B_WATCH: led = (t % 1000) < 500; break;
    case B_WARNING: led = (t % 500) < 250; buz = (t % 2000) < 100; break;
    case B_DANGER: led = true; buz = (t % 1000) < 500; break;
    default: {  // unknown: double blip
      uint32_t p = t % 2000;
      led = p < 100 || (p >= 250 && p < 350);
    }
  }
  digitalWrite(LED_PIN, led);
#if BUZZER_PIN >= 0
  digitalWrite(BUZZER_PIN, buz);
#endif
}

// ---------------------------------------------------------- local API
void fmtFloat(char* out, size_t n, float v) {
  if (isnan(v)) snprintf(out, n, "null");
  else snprintf(out, n, "%.1f", v);
}

void handleReading() {
  char water[16], rise[16], buf[260];
  fmtFloat(water, sizeof water, curWater);
  fmtFloat(rise, sizeof rise, curRise);
  snprintf(buf, sizeof buf,
           "{\"id\":\"%s\",\"band\":\"%s\",\"fault\":\"%s\",\"waterCm\":%s,\"riseCmH\":%s,"
           "\"ageS\":%lu,\"buffered\":%u,\"rssi\":%d,\"seq\":%lu}",
           STATION_ID, BAND_NAME[curBand], FAULT_NAME[curFault], water, rise,
           haveSample ? (unsigned long)((millis() - lastSampleMs) / 1000) : 0UL,
           (unsigned)ringCount, WiFi.RSSI(), (unsigned long)seq);
  server.send(200, "application/json", buf);
}

// ---------------------------------------------------------- setup/loop
// Prints the result of each step: if the watchdog is not active, it must show on the bench.
void wdtInit() {
  esp_err_t e;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_task_wdt_config_t cfg = {};
  cfg.timeout_ms = WDT_TIMEOUT_S * 1000;
  cfg.idle_core_mask = 0;
  cfg.trigger_panic = true;
  e = esp_task_wdt_reconfigure(&cfg);
  if (e == ESP_ERR_INVALID_STATE) e = esp_task_wdt_init(&cfg);  // not initialised yet
#else
  e = esp_task_wdt_init(WDT_TIMEOUT_S, true);
#endif
  Serial.printf("watchdog config: %d (0 = ok)
", (int)e);
  e = esp_task_wdt_add(NULL);
  Serial.printf("watchdog add: %d (0 = ok)
", (int)e);
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
#if BUZZER_PIN >= 0
  pinMode(BUZZER_PIN, OUTPUT);
#endif
  initSeq();
  wdtInit();

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  // The node works without Wi-Fi: wait briefly, then carry on and buffer.
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    esp_task_wdt_reset();
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Local reading: http://");
    Serial.print(WiFi.localIP());
    Serial.println("/reading");
  } else {
    Serial.println("No Wi-Fi yet, buffering readings");
  }
  server.on("/reading", handleReading);
  server.begin();
  nextSampleMs = nextFlushMs = nextWifiTryMs = millis();
}

// Timers use (int32_t)(millis() - due) >= 0, which only works if "due" was set from
// millis(). Setting "due now" to 0 would stop firing after ~24.8 days of uptime.
void loop() {
  esp_task_wdt_reset();
  uint32_t now = millis();

  if ((int32_t)(now - nextSampleMs) >= 0) {
    takeSample();
    nextSampleMs = millis() + intervalNow();
  }
  if (ringCount && (int32_t)(millis() - nextFlushMs) >= 0) {
    nextFlushMs = flushBuffer() ? millis() : millis() + RETRY_MS;
  }
  if (WiFi.status() != WL_CONNECTED && (int32_t)(now - nextWifiTryMs) >= 0) {
    WiFi.reconnect();
    nextWifiTryMs = now + WIFI_RETRY_MS;
  }
  updateAlarm();
  server.handleClient();
}
