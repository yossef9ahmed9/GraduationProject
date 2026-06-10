/*
  MediTrack MAX30102 Sensor — WiFi Provisioning Mode
  ====================================================
  Hardware : ESP32 + MAX30102

  FIRST BOOT (no config saved):
    1. ESP32 starts as WiFi Access Point: "MediTrack-Setup" (no password)
    2. Flutter app connects to it and POSTs:
         POST http://192.168.4.1/provision
         { "patientId": 14, "ssid": "HomeWiFi", "password": "pass123",
           "serverUrl": "http://192.168.1.6:5098/api/vitalsigns/sensor" }
    3. ESP32 saves config to Flash (Preferences), restarts in normal mode

  NORMAL BOOT (config saved):
    1. Connects to saved WiFi
    2. Reads MAX30102 every 30s, POSTs averaged vitals to backend
    3. RESET button (GPIO 0 / BOOT button) held 3s → clears config → back to AP mode

  Libraries (install via Arduino Library Manager):
    - "SparkFun MAX3010x Pulse and Proximity Sensor Library"
    - "ArduinoJson" by Benoit Blanchon
    - "Preferences" (built-in with ESP32 core)

  Wiring:
    MAX30102 VCC → 3.3V
    MAX30102 GND → GND
    MAX30102 SDA → GPIO 21
    MAX30102 SCL → GPIO 22
*/

#include <Wire.h>
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "spo2_algorithm.h"

// ── Pins ──────────────────────────────────────────────────────
const int ALERT_LED  = 2;   // built-in LED
const int BUZZER_PIN = 4;   // optional buzzer
const int RESET_PIN  = 0;   // BOOT button → hold 3s to clear config

// ── AP credentials ────────────────────────────────────────────
const char* AP_SSID = "MediTrack-Setup";   // open network, no password

// ── Saved config (loaded from Flash) ─────────────────────────
String  savedSSID, savedPass, savedUrl;
int     savedPatientId = 0;

// ── Runtime ───────────────────────────────────────────────────
Preferences prefs;
WebServer   server(80);
MAX30105    sensor;

// SpO2 buffers
const byte  BUFFER_SIZE = 100;
uint32_t    irBuffer[BUFFER_SIZE];
uint32_t    redBuffer[BUFFER_SIZE];

// BPM window
const int    WINDOW_SEC = 30;
unsigned long windowStart = 0;
float  bpmSum = 0, bpmMin = 999, bpmMax = 0;
float  spo2Sum = 0, spo2Min = 100;
int    sampleCount = 0;

// IBI / HRV
const byte IBI_SIZE = 20;
float  ibiBuffer[IBI_SIZE];
byte   ibiSpot = 0;
bool   ibiBufferFull = false;
long   lastBeat = 0;

bool   configMode = false;   // true = AP provisioning mode


// ═════════════════════════════════════════════════════════════
// FLASH helpers
// ═════════════════════════════════════════════════════════════

bool loadConfig() {
  prefs.begin("meditrack", true);   // read-only
  savedSSID      = prefs.getString("ssid",      "");
  savedPass      = prefs.getString("pass",      "");
  savedUrl       = prefs.getString("url",       "");
  savedPatientId = prefs.getInt   ("patientId", 0);
  prefs.end();
  return savedSSID.length() > 0 && savedPatientId > 0;
}

void saveConfig(const String& ssid, const String& pass,
                const String& url,  int patientId) {
  prefs.begin("meditrack", false);  // read-write
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
  WiFi.softAP(AP_SSID);   // open — no password
  Serial.println("AP IP: " + WiFi.softAPIP().toString());

  // Blink LED to signal AP mode
  for (int i = 0; i < 6; i++) {
    digitalWrite(ALERT_LED, HIGH); delay(200);
    digitalWrite(ALERT_LED, LOW);  delay(200);
  }

  // ── POST /provision ──────────────────────────────────────
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

    String  ssid      = doc["ssid"]      | "";
    String  pass      = doc["password"]  | "";
    String  url       = doc["serverUrl"] | "";
    int     patientId = doc["patientId"] | 0;

    if (ssid.isEmpty() || patientId == 0) {
      server.send(400, "application/json",
                  "{\"error\":\"ssid and patientId are required\"}");
      return;
    }

    // Default URL if not provided
    if (url.isEmpty()) {
      url = "http://192.168.1.6:5098/api/vitalsigns/sensor";
    }

    saveConfig(ssid, pass, url, patientId);
    server.send(200, "application/json",
                "{\"message\":\"Config saved. Rebooting...\"}");

    Serial.println("Config received — rebooting in 1s");
    delay(1000);
    ESP.restart();
  });

  // ── GET /status ──────────────────────────────────────────
  server.on("/status", HTTP_GET, []() {
    server.send(200, "application/json",
                "{\"mode\":\"provisioning\",\"device\":\"MediTrack-ESP32\"}");
  });

  server.begin();
  Serial.println("Provisioning server started. Waiting for config...");
}


// ═════════════════════════════════════════════════════════════
// NORMAL MODE helpers
// ═════════════════════════════════════════════════════════════

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

void clearAlert() {
  digitalWrite(ALERT_LED, LOW);
  noTone(BUZZER_PIN);
}

void sendToAPI(float bpmAvg, float spo2Avg) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected — skipping send.");
    return;
  }

  StaticJsonDocument<128> doc;
  doc["patientId"]        = savedPatientId;
  doc["heartRate"]        = (int)round(bpmAvg);
  doc["oxygenSaturation"] = round(spo2Avg * 10.0) / 10.0;

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
      }
    }
  } else {
    Serial.printf("API error: HTTP %d\n", code);
  }

  http.end();
}


// ═════════════════════════════════════════════════════════════
// SETUP
// ═════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  pinMode(ALERT_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(RESET_PIN, INPUT_PULLUP);

  // Hold BOOT button on power-on → clear config
  delay(100);
  if (digitalRead(RESET_PIN) == LOW) {
    Serial.println("RESET button held — clearing config...");
    delay(2900);
    if (digitalRead(RESET_PIN) == LOW) {
      clearConfig();   // never returns
    }
  }

  bool hasConfig = loadConfig();

  if (!hasConfig) {
    // ── No config → start AP provisioning mode ───────────
    startAPMode();
    return;
  }

  // ── Has config → normal sensor mode ─────────────────────
  Serial.printf("\nPatient ID : %d\n", savedPatientId);
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

  // Init MAX30102
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 not found. Check wiring!");
    while (1);
  }
  sensor.setup(60, 4, 2, 100, 411, 4096);

  windowStart = millis();
  Serial.println("Sensor ready. Place finger firmly on sensor.");
}


// ═════════════════════════════════════════════════════════════
// LOOP
// ═════════════════════════════════════════════════════════════

void loop() {
  // In AP mode — handle HTTP clients
  if (configMode) {
    server.handleClient();
    return;
  }

  // Check RESET button during normal operation (hold 3s)
  if (digitalRead(RESET_PIN) == LOW) {
    Serial.println("RESET held — will clear config in 3s...");
    delay(3000);
    if (digitalRead(RESET_PIN) == LOW) clearConfig();
  }

  // Fill SpO2/HR buffer
  for (byte i = 0; i < BUFFER_SIZE; i++) {
    while (!sensor.available()) sensor.check();
    redBuffer[i] = sensor.getRed();
    irBuffer[i]  = sensor.getIR();
    sensor.nextSample();
  }

  int32_t spo2Val, hrVal;
  int8_t  spo2Valid, hrValid;
  maxim_heart_rate_and_oxygen_saturation(
    irBuffer, BUFFER_SIZE, redBuffer,
    &spo2Val, &spo2Valid, &hrVal, &hrValid
  );

  if (hrValid && spo2Valid && hrVal > 20 && hrVal < 250) {
    float bpm  = (float)hrVal;
    float spo2 = (float)spo2Val;

    long now = millis();
    long ibi = now - lastBeat;
    if (ibi > 300 && ibi < 2000) {
      ibiBuffer[ibiSpot % IBI_SIZE] = (float)ibi;
      ibiSpot++;
      if (ibiSpot >= IBI_SIZE) ibiBufferFull = true;
    }
    lastBeat = now;

    bpmSum  += bpm;   spo2Sum += spo2;
    if (bpm  < bpmMin)  bpmMin  = bpm;
    if (bpm  > bpmMax)  bpmMax  = bpm;
    if (spo2 < spo2Min) spo2Min = spo2;
    sampleCount++;

    Serial.printf("BPM=%.0f | SpO2=%.1f%%\n", bpm, spo2);
  }

  if ((millis() - windowStart) >= (WINDOW_SEC * 1000UL) && sampleCount > 0) {
    sendToAPI(bpmSum / sampleCount, spo2Sum / sampleCount);
    bpmSum = 0; bpmMin = 999; bpmMax = 0;
    spo2Sum = 0; spo2Min = 100;
    sampleCount = 0;
    windowStart = millis();
  }
}
