#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <math.h>

MAX30105 sensor;

// ================= BPM =================
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
byte validRates = 0;
long lastBeat = 0;
float bpm = 0;
int bpmAvg = 0;

// ================= SpO2 =================
const int SPO2_SAMPLES = 100;
long irBuffer[SPO2_SAMPLES];
long redBuffer[SPO2_SAMPLES];
int spo2Index = 0;
float spo2Filtered = 0;

// ================= Timing =================
unsigned long lastPrint = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(8, 9);
  Wire.setClock(400000);

  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found. Check wiring/power.");
    while (1);
  }

  // Lower brightness + smaller adcRange + no averaging = sharper peaks
  sensor.setup(0x1F, 1, 2, 50, 411, 4096);
  sensor.setPulseAmplitudeRed(0x1F);
  sensor.setPulseAmplitudeIR(0x1F);
  sensor.setPulseAmplitudeGreen(0);

  Serial.println("Place finger firmly and flat on sensor...");
  Serial.println("Waiting for signal...");
}

void loop() {
  sensor.check();

  while (sensor.available()) {
    long ir  = sensor.getIR();
    long red = sensor.getRed();
    sensor.nextSample();
    processSample(ir, red);
  }

  // Print every 200ms
  if (millis() - lastPrint >= 200) {
    lastPrint = millis();
    printData();
  }
}

void printData() {
  long lastIR  = irBuffer[(spo2Index - 1 + SPO2_SAMPLES) % SPO2_SAMPLES];
  long lastRED = redBuffer[(spo2Index - 1 + SPO2_SAMPLES) % SPO2_SAMPLES];

  Serial.print("IR: ");        Serial.print(lastIR);
  Serial.print(" | RED: ");    Serial.print(lastRED);
  Serial.print(" | BPM: ");    Serial.print(bpm, 1);
  Serial.print(" | Avg BPM: "); Serial.print(bpmAvg);
  Serial.print(" | SpO2: ");

  if (spo2Filtered > 0)
    Serial.print(spo2Filtered, 1);
  else
    Serial.print("Calculating...");

  if (lastIR < 30000)
    Serial.print(" | Weak signal - place finger properly");
  else if (lastIR > 200000)
    Serial.print(" | Signal too strong - lift finger slightly");

  Serial.println();
}

void processSample(long ir, long red) {
  bool weakSignal = ir < 30000;

  if (weakSignal) {
    bpm        = 0;
    bpmAvg     = 0;
    spo2Filtered = 0;
    spo2Index  = 0;
    lastBeat   = 0;
    validRates = 0;
    rateSpot   = 0;
    for (byte i = 0; i < RATE_SIZE; i++) rates[i] = 0;
    return;
  }

  // ===== BPM Detection =====
  if (checkForBeat(ir)) {
    long now = millis();

    if (lastBeat > 0) {
      long delta = now - lastBeat;

      // Valid delta = 200ms to 2000ms (maps to 30–300 BPM)
      if (delta > 200 && delta < 2000) {
        float currentBpm = 60000.0 / (float)delta;

        if (currentBpm >= 40 && currentBpm <= 180) {
          bpm = currentBpm;
          rates[rateSpot++] = (byte)bpm;
          rateSpot %= RATE_SIZE;
          if (validRates < RATE_SIZE) validRates++;

          long sum = 0;
          for (byte i = 0; i < validRates; i++) sum += rates[i];
          bpmAvg = sum / validRates;
        }
      }
    }
    lastBeat = now;
  }

  // ===== SpO2 Buffering =====
  irBuffer[spo2Index]  = ir;
  redBuffer[spo2Index] = red;
  spo2Index++;

  if (spo2Index >= SPO2_SAMPLES) {
    spo2Index = 0;
    calculateSpO2();
  }
}

void calculateSpO2() {
  // Step 1: DC component (mean)
  double irMean = 0, redMean = 0;
  for (int i = 0; i < SPO2_SAMPLES; i++) {
    irMean  += irBuffer[i];
    redMean += redBuffer[i];
  }
  irMean  /= SPO2_SAMPLES;
  redMean /= SPO2_SAMPLES;

  // Step 2: AC component (RMS)
  double irAC = 0, redAC = 0;
  for (int i = 0; i < SPO2_SAMPLES; i++) {
    irAC  += pow(irBuffer[i]  - irMean,  2);
    redAC += pow(redBuffer[i] - redMean, 2);
  }
  irAC  = sqrt(irAC  / SPO2_SAMPLES);
  redAC = sqrt(redAC / SPO2_SAMPLES);

  // Step 3: Guard against bad signal
  if (irAC <= 0 || redAC <= 0 || irMean <= 0 || redMean <= 0) return;

  // Step 4: R ratio
  double ratio = (redAC / redMean) / (irAC / irMean);

  // Step 5: Empirical SpO2 formula
  float calculatedSpO2 = 110.0 - 25.0 * ratio;

  // Step 6: Clamp to valid range
  if (calculatedSpO2 > 100) calculatedSpO2 = 100;
  if (calculatedSpO2 < 70)  calculatedSpO2 = 70;

  // Step 7: Accept only physiologically valid values + smooth
  if (calculatedSpO2 >= 85 && calculatedSpO2 <= 100) {
    if (spo2Filtered == 0)
      spo2Filtered = calculatedSpO2;
    else
      spo2Filtered = (spo2Filtered * 0.85) + (calculatedSpO2 * 0.15);
  }
}