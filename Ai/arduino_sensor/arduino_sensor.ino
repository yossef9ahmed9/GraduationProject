/*
  MediTrack MAX30102 Sensor — WiFi Provisioning Mode
  ====================================================
  Hardware : ESP32-C3 + MAX30102

  Wiring:
    MAX30102 VCC → 3.3V
    MAX30102 GND → GND
    MAX30102 SDA → GPIO 8
    MAX30102 SCL → GPIO 9
*/

#include <Wire.h>
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <math.h>
#include "MAX30105.h"
#include "heartRate.h"      // checkForBeat()

// ── Pins ──────────────────────────────────────────────────────
const int ALERT_LED  = 2;
const int BUZZER_PIN = 4;
const int RESET_PIN  = 0;

// ── AP credentials ────────────────────────────────────────────
const char* AP_SSID = "MediTrack-Setup";

// ── Saved config ──────────────────────────────────────────────
String savedSSID, savedPass, savedUrl;
int    savedPatientId = 0;

// ── Runtime ───────────────────────────────────────────────────
Preferences prefs;
WebServer   server(80);
MAX30105    sensor;

// ── BPM (beat-by-beat sliding window) ────────────────────────
const byte RATE_SIZE = 8;
byte  rates[RATE_SIZE];
byte  rateSpot  = 0;
byte  validRates = 0;
long  lastBeat  = 0;
float liveBpm   = 0;
int   bpmAvg    = 0;

// ── SpO2 (manual R-ratio + IIR filter) ───────────────────────
const int SPO2_SAMPLES = 100;
long  irBuffer[SPO2_SAMPLES];
long  redBuffer[SPO2_SAMPLES];
int   spo2Index    = 0;
float spo2Filtered = 0;

// ── 30-second reporting window ────────────────────────────────
const int     WINDOW_SEC  = 30;
unsigned long windowStart = 0;
float  bpmSum = 0;
float  spo2Sum = 0;
int    sampleCount = 0;

// ── Finger detection threshold ────────────────────────────────
const long IR_FINGER_THRESHOLD = 30000;

bool configMode = false;


// ═════════════════════════════════════════════════════════════
// FLASH HELPERS
// ═════════════════════════════════════════════════════════════

bool loadConfig() {
  prefs.begin("meditrack", true);
  savedSSID      = prefs.getString("ssid",      "");
  savedPass      = prefs.getString("pass",      "");
  savedUrl       = prefs.getString("url",       "");
  savedPatientId = prefs.getInt   ("patientId", 0);
  prefs.end();
  return savedSSID.length() > 0 && savedPatientId > 0;
}

void saveConfig(const String& ssid, const String& pass,
                const String& url, int patientId) {
  prefs.begin("meditrack", false);
  prefs.putString("ssid",      ssid);
  prefs.putString("pass",      pass);
  prefs.putString("url",       url);
  prefs.putInt   ("patientId", patientId);
  prefs.end();
}

void clearConfig() {
  prefs.begin("meditrack", false);
  prefs.clear();
  prefs.end();
  Serial.println("Config cleared. Rebooting into AP mode...");
  delay(500);
  ESP.restart();
}


// ═════════════════════════════════════════════════════════════
// AP / PROVISIONING MODE
// ═════════════════════════════════════════════════════════════

void startAPMode() {
  configMode = true;
  Serial.println("\n=== PROVISIONING MODE ===");
  Serial.println("AP: " + String(AP_SSID));
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID);
  Serial.println("AP IP: " + WiFi.softAPIP().toString());

  for (int i = 0; i < 6; i++) {
    digitalWrite(ALERT_LED, HIGH); delay(200);
    digitalWrite(ALERT_LED, LOW);  delay(200);
  }

  server.on("/provision", HTTP_POST, []() {
    if (!server.hasArg("plain")) {
      server.send(400, "application/json", "{\"error\":\"No body\"}");
      return;
    }
    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, server.arg("plain"))) {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
      return;
    }
    String ssid      = doc["ssid"]      | "";
    String pass      = doc["password"]  | "";
    String url       = doc["serverUrl"] | "";
    int    patientId = doc["patientId"] | 0;

    if (ssid.isEmpty() || patientId == 0) {
      server.send(400, "application/json",
                  "{\"error\":\"ssid and patientId are required\"}");
      return;
    }
    if (url.isEmpty())
      url = "http://192.168.1.6:5098/api/vitalsigns/sensor";

    saveConfig(ssid, pass, url, patientId);
    server.send(200, "application/json",
                "{\"message\":\"Config saved. Rebooting...\"}");
    Serial.println("Config received — rebooting in 1s");
    delay(1000);
    ESP.restart();
  });

  server.on("/status", HTTP_GET, []() {
    server.send(200, "application/json",
                "{\"mode\":\"provisioning\",\"device\":\"MediTrack-ESP32\"}");
  });

  server.begin();
  Serial.println("Provisioning server started. Waiting for config...");
}


// ═════════════════════════════════════════════════════════════
// ALGORITHM — SpO2 (manual R-ratio)
// ═════════════════════════════════════════════════════════════

void calculateSpO2() {
  // DC component
  double irMean = 0, redMean = 0;
  for (int i = 0; i < SPO2_SAMPLES; i++) {
    irMean  += irBuffer[i];
    redMean += redBuffer[i];
  }
  irMean  /= SPO2_SAMPLES;
  redMean /= SPO2_SAMPLES;

  // AC component (RMS)
  double irAC = 0, redAC = 0;
  for (int i = 0; i < SPO2_SAMPLES; i++) {
    irAC  += pow(irBuffer[i]  - irMean,  2);
    redAC += pow(redBuffer[i] - redMean, 2);
  }
  irAC  = sqrt(irAC  / SPO2_SAMPLES);
  redAC = sqrt(redAC / SPO2_SAMPLES);

  if (irAC <= 0 || redAC <= 0 || irMean <= 0 || redMean <= 0) return;

  // R ratio → empirical SpO2
  double ratio = (redAC / redMean) / (irAC / irMean);
  float  spo2  = 110.0 - 25.0 * ratio;

  // Clamp
  spo2 = constrain(spo2, 70.0, 100.0);

  // Accept only valid range, then IIR smooth
  if (spo2 >= 85.0 && spo2 <= 100.0) {
    if (spo2Filtered == 0)
      spo2Filtered = spo2;
    else
      spo2Filtered = (spo2Filtered * 0.85f) + (spo2 * 0.15f);
  }
}


// ═════════════════════════════════════════════════════════════
// ALGORITHM — per-sample processing
// ═════════════════════════════════════════════════════════════

void processSample(long ir, long red) {
  // ── No finger ────────────────────────────────────────────
  if (ir < IR_FINGER_THRESHOLD) {
    liveBpm = 0; bpmAvg = 0; spo2Filtered = 0;
    spo2Index = 0; lastBeat = 0; validRates = 0; rateSpot = 0;
    for (byte i = 0; i < RATE_SIZE; i++) rates[i] = 0;
    return;
  }

  // ── BPM (beat detection) ──────────────────────────────────
  if (checkForBeat(ir)) {
    long now   = millis();
    long delta = now - lastBeat;

    if (lastBeat > 0 && delta > 200 && delta < 2000) {
      float currentBpm = 60000.0f / (float)delta;

      if (currentBpm >= 40 && currentBpm <= 180) {
        liveBpm = currentBpm;
        rates[rateSpot++] = (byte)liveBpm;
        rateSpot %= RATE_SIZE;
        if (validRates < RATE_SIZE) validRates++;

        long sum = 0;
        for (byte i = 0; i < validRates; i++) sum += rates[i];
        bpmAvg = sum / validRates;
      }
    }
    lastBeat = now;
  }

  // ── SpO2 buffering ────────────────────────────────────────
  irBuffer[spo2Index]  = ir;
  redBuffer[spo2Index] = red;
  spo2Index++;
  if (spo2Index >= SPO2_SAMPLES) {
    spo2Index = 0;
    calculateSpO2();
  }
}


// ═════════════════════════════════════════════════════════════
// ALERT HELPERS
// ═════════════════════════════════════════════════════════════

void triggerCriticalAlert() {
  Serial.println("!!! CRITICAL ALERT — AMBULANCE TRIGGERED !!!");
  for (int i = 0; i < 15; i++) {
    digitalWrite(ALERT_LED, HIGH); delay(150);
    digitalWrite(ALERT_LED, LOW);  delay(100);
  }
}

void clearAlert() {
  digitalWrite(ALERT_LED, LOW);
}


// ═════════════════════════════════════════════════════════════
// API SEND
// ═════════════════════════════════════════════════════════════

void sendToAPI(float bpmToSend, float spo2ToSend) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected — skipping send.");
    return;
  }

  StaticJsonDocument<128> doc;
  doc["patientId"]        = savedPatientId;
  doc["heartRate"]        = (int)round(bpmToSend);
  doc["oxygenSaturation"] = round(spo2ToSend * 10.0) / 10.0;

  String body;
  serializeJson(doc, body);
  Serial.println("Sending → " + body);

  HTTPClient http;
  http.begin(savedUrl);
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
        triggerCriticalAlert();
        if (dispatched) Serial.println(">>> Ambulance dispatched!");
      } else {
        clearAlert();
        Serial.println("✅ Normal reading saved.");
      }
    }
  } else {
    Serial.printf("API error: HTTP %d\n", code);
    Serial.println(http.getString());
  }
  http.end();
}


// ═════════════════════════════════════════════════════════════
// SETUP
// ═════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  pinMode(ALERT_LED,  OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RESET_PIN,  INPUT_PULLUP);

  delay(100);
  if (digitalRead(RESET_PIN) == LOW) {
    Serial.println("RESET held — clearing config in 3s...");
    delay(2900);
    if (digitalRead(RESET_PIN) == LOW) clearConfig();
  }

  bool hasConfig = loadConfig();
  if (!hasConfig) { startAPMode(); return; }

  Serial.printf("\nPatient ID : %d\n",  savedPatientId);
  Serial.println("WiFi SSID  : " + savedSSID);
  Serial.println("Server URL : " + savedUrl);

  Serial.print("Connecting to WiFi");
  WiFi.begin(savedSSID.c_str(), savedPass.c_str());
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500); Serial.print("."); tries++;
  }
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi failed — back to AP mode");
    startAPMode();
    return;
  }
  Serial.println("\nConnected: " + WiFi.localIP().toString());
  digitalWrite(ALERT_LED, HIGH); delay(300); digitalWrite(ALERT_LED, LOW);

  // ── Init MAX30102 ─────────────────────────────────────────
  Wire.end();
  delay(100);
  Wire.begin(8, 9);          // SDA=8, SCL=9
  Wire.setClock(400000);     // Fast mode (same as reference sketch)
  delay(200);

  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 not found. Check wiring!");
    while (1) {
      digitalWrite(ALERT_LED, HIGH); delay(300);
      digitalWrite(ALERT_LED, LOW);  delay(300);
    }
  }

  // Lower brightness (0x1F), no averaging (1), 50 Hz sample rate
  // → sharper peaks, better beat detection
  sensor.setup(0x1F, 1, 2, 50, 411, 4096);
  sensor.setPulseAmplitudeRed(0x1F);
  sensor.setPulseAmplitudeIR(0x1F);
  sensor.setPulseAmplitudeGreen(0);

  windowStart = millis();
  Serial.println("Sensor ready. Place finger firmly on sensor.");
}


// ═════════════════════════════════════════════════════════════
// LOOP
// ═════════════════════════════════════════════════════════════

void loop() {
  if (configMode) { server.handleClient(); return; }

  if (digitalRead(RESET_PIN) == LOW) {
    Serial.println("RESET held — clearing in 3s...");
    delay(3000);
    if (digitalRead(RESET_PIN) == LOW) clearConfig();
  }

  // ── Drain sensor FIFO (non-blocking) ─────────────────────
  sensor.check();
  while (sensor.available()) {
    long ir  = sensor.getIR();
    long red = sensor.getRed();
    sensor.nextSample();
    processSample(ir, red);
  }

  // ── 30-second window → send average ──────────────────────
  if (bpmAvg > 0 && spo2Filtered > 0) {
    bpmSum  += bpmAvg;
    spo2Sum += spo2Filtered;
    sampleCount++;
    Serial.printf("BPM=%d | SpO2=%.1f%%\n", bpmAvg, spo2Filtered);
  }

  if ((millis() - windowStart) >= (WINDOW_SEC * 1000UL) && sampleCount > 0) {
    sendToAPI(bpmSum / sampleCount, spo2Sum / sampleCount);
    bpmSum = 0; spo2Sum = 0; sampleCount = 0;
    windowStart = millis();
  }
}