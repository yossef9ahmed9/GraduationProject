#include <Preferences.h>

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Preferences prefs;
  prefs.begin("meditrack", false);
  prefs.clear();
  prefs.end();
  
  Serial.println("Flash cleared! Now upload the main sensor code.");
}

void loop() {}
