import requests
import time
import random

BASE_URL   = "http://192.168.1.6:5098"
TOKEN      = "YOUR_PATIENT_JWT_TOKEN_HERE"   # ← غيّره
PATIENT_ID = 2                               # ← غيّره

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {TOKEN}"
}


def send_vital(hr, spo2, label=""):
    res  = requests.post(
        f"{BASE_URL}/api/vitalsigns/sensor",
        headers=HEADERS,
        json={"heartRate": hr, "oxygenSaturation": spo2}
    )
    data = res.json()
    emg  = data.get("isEmergency", False)
    print(f"  {label:35} HR={hr:3}  SpO2={spo2:.1f}%  {'🚨 EMERGENCY' if emg else '✅ ok'}")
    time.sleep(4)


# ── SCENARIO 1 — Healthy baseline ────────────────────────────────
print("\n" + "="*60)
print("SCENARIO 1 — Healthy baseline (should stay STABLE)")
print("="*60)
for i in range(6):
    send_vital(
        hr   = random.randint(65, 80),
        spo2 = round(random.uniform(97, 99), 1),
        label=f"Normal reading #{i+1}",
    )

# ── SCENARIO 2 — Gradual deterioration ───────────────────────────
print("\n" + "="*60)
print("SCENARIO 2 — Gradual deterioration (TOWARD_EMERGENCY)")
print("="*60)
steps = [
    ( 82, 96.5, "Slight rise"),
    ( 88, 96.0, "Getting worse"),
    ( 95, 95.2, "Worsening"),
    (105, 94.0, "Warning zone"),
    (118, 93.0, "Approaching critical"),
    (130, 91.5, "Near critical"),
    (145, 90.0, "Critical threshold"),
]
for hr, spo2, label in steps:
    send_vital(hr, spo2, label)

# ── SCENARIO 3 — Recovery ────────────────────────────────────────
print("\n" + "="*60)
print("SCENARIO 3 — Recovery (AWAY_FROM_EMERGENCY)")
print("="*60)
for i in range(5):
    hr   = 130 - (i * 12)
    spo2 = 90.0 + (i * 1.5)
    send_vital(hr, round(spo2, 1), f"Recovery #{i+1}")

# ── SCENARIO 4 — Low SpO2 (hypoxia path) ─────────────────────────
print("\n" + "="*60)
print("SCENARIO 4 — Low SpO2 (hypoxia path)")
print("="*60)
for i in range(5):
    send_vital(
        hr   = random.randint(75, 95),
        spo2 = round(97.0 - (i * 1.8), 1),
        label=f"SpO2 dropping #{i+1}",
    )

print("\nSimulation complete.")
