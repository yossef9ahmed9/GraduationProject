"""
test_sensor.py
==============
Simulates the ESP32 MAX30102 sensor sending vital signs to the .NET backend.
Useful for testing without physical hardware.

Usage:
    python test_sensor.py                  # single shot with default values
    python test_sensor.py --loop           # sends every 30s like the real Arduino
    python test_sensor.py --hr 155 --spo2 88   # custom values (triggers emergency)
    python test_sensor.py --patient 2     # different patient ID

Requirements:
    pip install requests
"""

import argparse
import time
import random
import requests
import json
from datetime import datetime

# ─── CONFIG — change these to match your setup ───────────────────────────────
API_URL    = "http://192.168.1.6:5098/api/vitalsigns/sensor"
PATIENT_ID = 1      # ← change to the patient ID in your database
INTERVAL   = 30     # seconds between sends (matches Arduino window)
# ─────────────────────────────────────────────────────────────────────────────


def send_reading(heart_rate: int, oxygen_saturation: float, patient_id: int, url: str = API_URL) -> dict:
    """Send one vital signs reading to the backend."""
    payload = {
        "patientId":        patient_id,
        "heartRate":        heart_rate,
        "oxygenSaturation": round(oxygen_saturation, 1),
    }

    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Sending → {json.dumps(payload)}")

    try:
        resp = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        result = resp.json()
        status = "✅ OK" if resp.ok else "❌ FAILED"
        print(f"  {status} ({resp.status_code}) → {json.dumps(result)}")

        if resp.ok and result.get("isEmergency"):
            print("  🚨 EMERGENCY TRIGGERED — ambulance dispatched!")

        return result

    except requests.exceptions.ConnectionError:
        print("  ❌ Cannot connect — is the server running?")
        return {}
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return {}


def generate_normal() -> tuple[int, float]:
    """Generate realistic normal vital signs."""
    hr   = random.randint(62, 95)
    spo2 = round(random.uniform(96.0, 99.5), 1)
    return hr, spo2


def generate_emergency_high_hr() -> tuple[int, float]:
    """Heart rate critically high — should trigger emergency."""
    hr   = random.randint(151, 180)
    spo2 = round(random.uniform(94.0, 97.0), 1)
    return hr, spo2


def generate_emergency_low_spo2() -> tuple[int, float]:
    """SpO2 critically low — should trigger emergency."""
    hr   = random.randint(70, 100)
    spo2 = round(random.uniform(84.0, 89.5), 1)
    return hr, spo2


def generate_emergency_low_hr() -> tuple[int, float]:
    """Heart rate critically low — should trigger emergency."""
    hr   = random.randint(25, 39)
    spo2 = round(random.uniform(94.0, 97.0), 1)
    return hr, spo2


# ─── Scenarios ────────────────────────────────────────────────────────────────
SCENARIOS = {
    "normal":         generate_normal,
    "high_hr":        generate_emergency_high_hr,
    "low_spo2":       generate_emergency_low_spo2,
    "low_hr":         generate_emergency_low_hr,
}


def main():
    parser = argparse.ArgumentParser(
        description="Simulate ESP32 MAX30102 sensor sending data to the backend."
    )
    parser.add_argument("--url",      default=API_URL,    help="Backend endpoint URL")
    parser.add_argument("--patient",  type=int, default=PATIENT_ID, help="Patient ID")
    parser.add_argument("--hr",       type=int,   default=None,  help="Fixed heart rate (bpm)")
    parser.add_argument("--spo2",     type=float, default=None,  help="Fixed SpO2 (%%)")
    parser.add_argument("--scenario", choices=list(SCENARIOS.keys()), default=None,
                        help="Preset scenario: normal | high_hr | low_spo2 | low_hr")
    parser.add_argument("--loop",     action="store_true",
                        help=f"Keep sending every {INTERVAL}s (like the real Arduino)")
    parser.add_argument("--count",    type=int, default=None,
                        help="How many readings to send in loop mode (default: infinite)")
    parser.add_argument("--interval", type=int, default=INTERVAL,
                        help=f"Seconds between loop sends (default: {INTERVAL})")

    args = parser.parse_args()

    print("=" * 60)
    print("  MediTrack Sensor Simulator")
    print("=" * 60)
    print(f"  Endpoint  : {args.url}")
    print(f"  Patient ID: {args.patient}")
    if args.loop:
        print(f"  Mode      : Loop every {args.interval}s")
        if args.count:
            print(f"  Count     : {args.count} readings")
    else:
        print("  Mode      : Single shot")
    print()

    endpoint = args.url
    count = 0
    while True:
        # Determine values for this reading
        if args.hr is not None and args.spo2 is not None:
            hr, spo2 = args.hr, args.spo2
        elif args.scenario:
            hr, spo2 = SCENARIOS[args.scenario]()
        elif args.hr is not None:
            hr, spo2 = args.hr, generate_normal()[1]
        elif args.spo2 is not None:
            hr, spo2 = generate_normal()[0], args.spo2
        else:
            hr, spo2 = generate_normal()

        send_reading(hr, spo2, args.patient, endpoint)
        count += 1

        if not args.loop:
            break

        if args.count and count >= args.count:
            print(f"\nDone — sent {count} readings.")
            break

        print(f"  Next reading in {args.interval}s… (Ctrl+C to stop)")
        try:
            time.sleep(args.interval)
        except KeyboardInterrupt:
            print(f"\nStopped after {count} readings.")
            break


if __name__ == "__main__":
    main()
