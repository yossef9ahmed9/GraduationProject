#include <Wire.h>

void scanPins(int sda, int scl) {
  Wire.begin(sda, scl);
  Serial.printf("\nSDA=GPIO%d  SCL=GPIO%d : ", sda, scl);
  int found = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("FOUND 0x%02X", addr);
      if (addr == 0x57) Serial.print(" <-- MAX30102!");
      found++;
    }
  }
  if (found == 0) Serial.print("nothing");
  Wire.end();
  delay(100);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== I2C Scan ===");
  scanPins(8, 9);
  scanPins(9, 8);
  scanPins(4, 5);
  scanPins(5, 4);
  scanPins(6, 7);
  scanPins(7, 6);
  scanPins(2, 3);
  scanPins(3, 2);
  Serial.println("\n=== Done ===");
}

void loop() {}
