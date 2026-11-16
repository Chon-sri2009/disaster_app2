// Tinkercad Circuits demo (Arduino Uno). Sensor + alarm logic only:
// no Wi-Fi, no signing, no buffer (Tinkercad cannot simulate an ESP32).
//
// Circuit:  Ultrasonic distance sensor (4 pins): VCC->5V, GND->GND, TRIG->7, ECHO->6
//           LED + 220 ohm resistor on pin 13 (to GND)
//           Piezo (buzzer) + on pin 8, - to GND
// Drag the sensor's "distance" slider in the simulator: far = low water, close = high water.
// Open the Serial Monitor to see the numbers.

const int TRIG_PIN = 7, ECHO_PIN = 6, LED_PIN = 13, BUZZER_PIN = 8;

const float SENSOR_HEIGHT_CM = 300;  // sensor face to zero level
const float MIN_VALID_CM = 25, MAX_VALID_CM = 330;  // Tinkercad sensor tops out ~336 cm
const float WATCH_CM = 120, WARNING_CM = 160, DANGER_CM = 185;
const float RISE_WATCH_CM_MIN = 10;  // demo: cm per MINUTE (real node uses cm/h over 10 min)
const int SAMPLES = 5;

const int N = 30;  // 30 readings at 1 s = 30 s window for the rise rate
float hist[N];
int histCount = 0, histHead = 0;
int band = 0;  // 0 unknown, 1 safe, 2 watch, 3 warning, 4 danger
const char* NAMES[] = {"UNKNOWN", "safe", "WATCH", "WARNING", "DANGER"};

float ping() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, 30000);
  if (us == 0) return -1;
  return us * 0.0343 / 2.0;
}

// Median of SAMPLES pings; -1 if fewer than 3 are valid.
float measure() {
  float v[SAMPLES];
  int n = 0;
  for (int i = 0; i < SAMPLES; i++) {
    float d = ping();
    if (d >= MIN_VALID_CM && d <= MAX_VALID_CM) v[n++] = d;
    delay(30);
  }
  if (n < 3) return -1;
  for (int i = 1; i < n; i++) {
    float x = v[i];
    int j = i - 1;
    while (j >= 0 && v[j] > x) { v[j + 1] = v[j]; j--; }
    v[j + 1] = x;
  }
  return v[n / 2];
}

void setup() {
  Serial.begin(9600);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
}

void loop() {
  float d = measure();
  float rise = 0;
  if (d < 0) {
    band = 0;  // no trustworthy reading: unknown, never safe
    histCount = 0;
    Serial.println("no valid echo -> UNKNOWN");
  } else {
    float water = SENSOR_HEIGHT_CM - d;
    hist[histHead] = water;
    histHead = (histHead + 1) % N;
    if (histCount < N) histCount++;
    if (histCount >= 10) {  // need 10 s of data
      float oldest = hist[(histHead + N - histCount) % N];
      rise = (water - oldest) / (histCount / 60.0);  // cm per minute
    }
    band = water >= DANGER_CM ? 4 : water >= WARNING_CM ? 3 : water >= WATCH_CM ? 2 : 1;
    if (rise >= RISE_WATCH_CM_MIN && band < 2) band = 2;
    Serial.print("distance ");
    Serial.print(d, 0);
    Serial.print(" cm  water ");
    Serial.print(water, 0);
    Serial.print(" cm  rise ");
    Serial.print(rise, 0);
    Serial.print(" cm/min  ");
    Serial.println(NAMES[band]);
  }

  // Alarm for ~1 s: pattern by band.
  for (int i = 0; i < 4; i++) {  // 4 x 250 ms
    bool led = false, buz = false;
    switch (band) {
      case 1: led = (i == 0); break;
      case 2: led = (i % 2 == 0); break;
      case 3: led = true; buz = (i == 0); break;
      case 4: led = true; buz = (i < 2); break;
      default: led = (i == 0 || i == 2);  // unknown: double blip
    }
    digitalWrite(LED_PIN, led);
    digitalWrite(BUZZER_PIN, buz);
    delay(250);
  }
  digitalWrite(BUZZER_PIN, LOW);
}
