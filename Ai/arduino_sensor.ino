/*
  MAX30102 → FastAPI Heart Risk Monitor
  ======================================
  Hardware : ESP32 + MAX30102 sensor
  Libraries needed (install via Arduino Library Manager):
    - "SparkFun MAX3010x Pulse and Proximity Sensor Library"
    - "ArduinoJson" by Benoit Blanchon

  Wiring:
    MAX30102 VCC → 3.3V
    MAX30102 GND → GND
    MAX30102 SDA → GPIO 21
    MAX30102 SCL → GPIO 22

  How it works:
    1. Reads BPM and SpO2 from MAX30102 continuously
    2. Calculates HRV from inter-beat intervals
    3. Every 30 seconds sends averaged window to FastAPI
    4. Reads response and triggers LED/buzzer alert if needed
*/

#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"

// ─────────────────────────────────────────────────────────────────
// *** CHANGE THESE TO MATCH YOUR SETUP ***
// ─────────────────────────────────────────────────────────────────
const char* WIFI_SSID   = "YOUR_WIFI_NAME";
const char* WIFI_PASS   = "YOUR_WIFI_PASSWORD";
const char* API_URL     = "http://YOUR_SERVER_IP:8000/predict/window";

const int   PATIENT_AGE = 45;   // patient age — change this
const int   PATIENT_SEX = 1;    // 1 = male, 0 = female

const int   ALERT_LED   = 2;    // built-in LED on most ESP32 boards
const int   BUZZER_PIN  = 4;    // optional buzzer pin
// ─────────────────────────────────────────────────────────────────

MAX30105 sensor;

// SpO2 buffer
const byte BUFFER_SIZE = 100;
uint32_t irBuffer[BUFFER_SIZE];
uint32_t redBuffer[BUFFER_SIZE];

// BPM
const byte RATE_SIZE = 4;
byte   rates[RATE_SIZE];
byte   rateSpot    = 0;
long   lastBeat    = 0;
float  currentBPM  = 0;

// IBI / HRV
const byte IBI_SIZE    = 20;
float  ibiBuffer[IBI_SIZE];
byte   ibiSpot         = 0;
bool   ibiBufferFull   = false;

// 30-second window
const int    WINDOW_SEC  = 30;
unsigned long windowStart = 0;
float  bpmSum  = 0, bpmMin = 999, bpmMax = 0;
float  spo2Sum = 0, spo2Min = 100;
int    sampleCount = 0;


// ─────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(ALERT_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Connect WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected: " + WiFi.localIP().toString());

  // Init MAX30102
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 not found. Check wiring!");
    while (1);
  }
  sensor.setup(60, 4, 2, 100, 411, 4096);

  windowStart = millis();
  Serial.println("Sensor ready. Place finger firmly on sensor.");
}


// ─────────────────────────────────────────────────────────────────
float calculateHRV() {
  int count = ibiBufferFull ? IBI_SIZE : ibiSpot;
  if (count < 2) return 50.0;
  float sumSq = 0;
  for (int i = 1; i < count; i++) {
    float diff = ibiBuffer[i] - ibiBuffer[i - 1];
    sumSq += diff * diff;
  }
  return sqrt(sumSq / (count - 1));
}


// ─────────────────────────────────────────────────────────────────
void triggerCriticalAlert() {
  Serial.println("!!! CRITICAL ALERT — AMBULANCE TRIGGERED !!!");
  for (int i = 0; i < 15; i++) {
    digitalWrite(ALERT_LED, HIGH);
    tone(BUZZER_PIN, 1000, 150);
    delay(150);
    digitalWrite(ALERT_LED, LOW);
    delay(100);
  }
}

void triggerWarningAlert() {
  Serial.println("WARNING — Doctor visit recommended");
  for (int i = 0; i < 3; i++) {
    digitalWrite(ALERT_LED, HIGH);
    tone(BUZZER_PIN, 600, 300);
    delay(400);
    digitalWrite(ALERT_LED, LOW);
    delay(200);
  }
}

void clearAlert() {
  digitalWrite(ALERT_LED, LOW);
  noTone(BUZZER_PIN);
}


// ─────────────────────────────────────────────────────────────────
void sendToAPI(float bpmAvg, float bpmMinVal, float bpmMaxVal,
               float spo2Avg, float spo2MinVal, float hrv) {

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected — skipping.");
    return;
  }

  // Build JSON body
  StaticJsonDocument<256> doc;
  doc["bpm_avg"]  = bpmAvg;
  doc["bpm_min"]  = bpmMinVal;
  doc["bpm_max"]  = bpmMaxVal;
  doc["spo2_avg"] = spo2Avg;
  doc["spo2_min"] = spo2MinVal;
  doc["hrv_ms"]   = hrv;
  doc["age"]      = PATIENT_AGE;
  doc["sex"]      = PATIENT_SEX;

  String body;
  serializeJson(doc, body);
  Serial.println("Sending: " + body);

  HTTPClient http;
  http.begin(API_URL);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);

  if (code == 200) {
    String response = http.getString();
    Serial.println("Response: " + response);

    StaticJsonDocument<512> res;
    deserializeJson(res, response);

    const char* tier   = res["tier"];
    float       score  = res["score"];
    bool        alert  = res["alert"];
    const char* action = res["action"];

    Serial.printf("TIER=%s | SCORE=%.1f | ALERT=%s\n", tier, score, alert ? "YES" : "NO");
    Serial.println("ACTION: " + String(action));

    if (alert) {
      triggerCriticalAlert();
    } else if (strcmp(tier, "WARNING") == 0) {
      triggerWarningAlert();
    } else {
      clearAlert();
    }

  } else {
    Serial.printf("API error: HTTP %d\n", code);
  }

  http.end();
}


// ─────────────────────────────────────────────────────────────────
void loop() {
  // Fill buffer
  for (byte i = 0; i < BUFFER_SIZE; i++) {
    while (!sensor.available()) sensor.check();
    redBuffer[i] = sensor.getRed();
    irBuffer[i]  = sensor.getIR();
    sensor.nextSample();
  }

  // Calculate SpO2 and HR
  int32_t spo2Val, hrVal;
  int8_t  spo2Valid, hrValid;
  maxim_heart_rate_and_oxygen_saturation(
    irBuffer, BUFFER_SIZE, redBuffer,
    &spo2Val, &spo2Valid, &hrVal, &hrValid
  );

  if (hrValid && spo2Valid && hrVal > 20 && hrVal < 250) {
    float bpm  = (float)hrVal;
    float spo2 = (float)spo2Val;

    // Track IBI for HRV
    long now = millis();
    long ibi = now - lastBeat;
    if (ibi > 300 && ibi < 2000) {
      ibiBuffer[ibiSpot % IBI_SIZE] = (float)ibi;
      ibiSpot++;
      if (ibiSpot >= IBI_SIZE) ibiBufferFull = true;
    }
    lastBeat = now;

    // Accumulate window
    bpmSum  += bpm;
    spo2Sum += spo2;
    if (bpm  < bpmMin)  bpmMin  = bpm;
    if (bpm  > bpmMax)  bpmMax  = bpm;
    if (spo2 < spo2Min) spo2Min = spo2;
    sampleCount++;

    Serial.printf("BPM=%.0f | SpO2=%.1f%% | HRV=%.1fms\n", bpm, spo2, calculateHRV());
  }

  // Every 30 seconds → send to API
  if ((millis() - windowStart) >= (WINDOW_SEC * 1000UL) && sampleCount > 0) {
    sendToAPI(
      bpmSum / sampleCount, bpmMin, bpmMax,
      spo2Sum / sampleCount, spo2Min,
      calculateHRV()
    );

    // Reset window
    bpmSum = 0; bpmMin = 999; bpmMax = 0;
    spo2Sum = 0; spo2Min = 100;
    sampleCount = 0;
    windowStart = millis();
  }
}
