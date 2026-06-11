/*
  arduino_sensor_test.ino
  ========================
  Quick test version — no provisioning, no app needed.
  Hardcode your WiFi + patient ID below and upload.
  Same sensor logic and API call as the main version.

  Change the 3 values below then upload.
*/

#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"

// ── *** CHANGE THESE *** ──────────────────────────────────────
const char* WIFI_SSID  = "YOUR_WIFI_NAME";
const char* WIFI_PASS  = "YOUR_WIFI_PASSWORD";
const int   PATIENT_ID = 1;
const char* API_URL    = "http://192.168.0.102:5098/api/vitalsigns/sensor";
// ─────────────────────────────────────────────────────────────

const int ALERT_LED  = 8;   // ESP32-C3 Mini built-in LED
const int WINDOW_SEC = 30;  // send every 30s (change to 10 for faster testing)

MAX30105 sensor;

const byte  SPO2_BUF_SIZE = 100;
uint32_t    irBuffer[SPO2_BUF_SIZE];
uint32_t    redBuffer[SPO2_BUF_SIZE];

unsigned long windowStart = 0;
float  bpmSum = 0, spo2Sum = 0;
int    sampleCount = 0;

long   lastBeat = 0;
const byte IBI_SIZE = 20;
float  ibiBuffer[IBI_SIZE];
byte   ibiSpot = 0;
bool   ibiBufferFull = false;


void setup() {
  Serial.begin(115200);
  pinMode(ALERT_LED, OUTPUT);

  // Connect WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500); Serial.print("."); tries++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi FAILED — check SSID/password");
    while (1) { digitalWrite(ALERT_LED, !digitalRead(ALERT_LED)); delay(200); }
  }

  Serial.println("\nConnected: " + WiFi.localIP().toString());
  digitalWrite(ALERT_LED, HIGH); delay(300); digitalWrite(ALERT_LED, LOW);

  // Init MAX30102
  Wire.begin(8, 9); // SDA=8, SCL=9 for ESP32-C3
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 not found. Check wiring!");
    while (1);
  }
  sensor.setup(60, 4, 2, 100, 411, 4096);

  windowStart = millis();
  Serial.println("=== Sensor ready — place finger firmly ===");
  Serial.printf("Patient ID : %d\n", PATIENT_ID);
  Serial.printf("Window     : %d seconds\n", WINDOW_SEC);
}


void sendReading(float bpmAvg, float spo2Avg) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost — skipping");
    return;
  }

  StaticJsonDocument<128> doc;
  doc["patientId"]        = PATIENT_ID;
  doc["heartRate"]        = (int)round(bpmAvg);
  doc["oxygenSaturation"] = round(spo2Avg * 10.0) / 10.0;

  String body;
  serializeJson(doc, body);
  Serial.println("\nSending → " + body);

  HTTPClient http;
  http.begin(API_URL);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);

  if (code == 200 || code == 201) {
    String resp = http.getString();
    Serial.println("Response: " + resp);

    StaticJsonDocument<256> res;
    if (!deserializeJson(res, resp)) {
      bool emergency  = res["isEmergency"]  | false;
      bool dispatched = res["autoDispatch"] | false;
      if (emergency) {
        Serial.println("🚨 EMERGENCY! Ambulance dispatched: " + String(dispatched ? "YES" : "NO"));
        // Flash LED fast for emergency
        for (int i = 0; i < 20; i++) {
          digitalWrite(ALERT_LED, HIGH); delay(100);
          digitalWrite(ALERT_LED, LOW);  delay(100);
        }
      } else {
        Serial.println("✅ Normal reading saved.");
        digitalWrite(ALERT_LED, HIGH); delay(200); digitalWrite(ALERT_LED, LOW);
      }
    }
  } else {
    Serial.printf("API error: HTTP %d\n", code);
    Serial.println(http.getString());
  }

  http.end();
}


void loop() {
  // Fill buffer
  for (byte i = 0; i < SPO2_BUF_SIZE; i++) {
    while (!sensor.available()) sensor.check();
    redBuffer[i] = sensor.getRed();
    irBuffer[i]  = sensor.getIR();
    sensor.nextSample();
  }

  int32_t spo2Val, hrVal;
  int8_t  spo2Valid, hrValid;
  maxim_heart_rate_and_oxygen_saturation(
    irBuffer, SPO2_BUF_SIZE, redBuffer,
    &spo2Val, &spo2Valid, &hrVal, &hrValid
  );

  if (hrValid && spo2Valid && hrVal > 20 && hrVal < 250) {
    bpmSum  += (float)hrVal;
    spo2Sum += (float)spo2Val;
    sampleCount++;
    Serial.printf("BPM=%d | SpO2=%d%% | samples=%d\n", hrVal, spo2Val, sampleCount);
  } else {
    Serial.println("No finger detected or invalid reading...");
  }

  if ((millis() - windowStart) >= (WINDOW_SEC * 1000UL) && sampleCount > 0) {
    sendReading(bpmSum / sampleCount, spo2Sum / sampleCount);
    bpmSum = 0; spo2Sum = 0; sampleCount = 0;
    windowStart = millis();
  }
}
