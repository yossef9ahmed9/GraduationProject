import requests
import time
import random

BASE_URL = "http://192.168.1.6:5098"

# غيّر الـ token ده لأي patient token حقيقي من التطبيق
TOKEN = "YOUR_PATIENT_JWT_TOKEN_HERE"

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {TOKEN}"
}

scenarios = [
    # (name, hr_range, spo2_range, count)
    ("Normal",   (65, 85),   (97, 99), 3),
    ("Warning",  (100, 115), (93, 95), 3),
    ("Critical", (155, 165), (86, 89), 2),
    ("Recovery", (70, 80),   (97, 99), 3),
]

for name, hr_range, spo2_range, count in scenarios:
    print(f"\n=== Scenario: {name} ===")
    for i in range(count):
        hr   = random.randint(*hr_range)
        spo2 = round(random.uniform(*spo2_range), 1)
        res  = requests.post(
            f"{BASE_URL}/api/vitalsigns/sensor",
            headers=HEADERS,
            json={"heartRate": hr, "oxygenSaturation": spo2}
        )
        data      = res.json()
        emergency = data.get("isEmergency", False)
        print(f"  HR={hr} SpO2={spo2}% → {'🚨 EMERGENCY' if emergency else '✅ Normal'}")
        time.sleep(3)  # 3 ثواني بين كل reading
