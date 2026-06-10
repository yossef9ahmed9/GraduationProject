"""
test_sensor.py
==============
Simulates the ESP32 MAX30102 sensor sending vital signs to the .NET backend.
Supports two modes:
  - JWT mode:       Login with patient email/password → token used automatically
  - Anonymous mode: Pass --patient ID (old behavior)

Usage:
    python test_sensor.py                        # JWT mode (prompts for login)
    python test_sensor.py --patient 14           # anonymous mode with patient ID
    python test_sensor.py --scenario high_hr     # emergency scenario
    python test_sensor.py --loop --interval 5    # continuous loop

Requirements:
    pip install requests
"""

import argparse
import time
import random
import requests
import json
from datetime import datetime
from getpass import getpass
from typing import Optional

# ─── CONFIG ───────────────────────────────────────────────────────────────────
BASE_URL   = "http://192.168.1.6:5098/api"
API_URL    = f"{BASE_URL}/vitalsigns/sensor"
LOGIN_URL  = f"{BASE_URL}/auth/login"
PATIENT_ID = 0       # 0 = use JWT mode
INTERVAL   = 30
# ─────────────────────────────────────────────────────────────────────────────


def login(email: str, password: str) -> Optional[str]:
    """Login and return JWT token."""
    try:
        resp = requests.post(
            LOGIN_URL,
            json={"email": email, "password": password},
            timeout=10,
        )
        if resp.ok:
            token = resp.json().get("token")
            print(f"  ✅ Logged in — patient ID resolved from JWT")
            return token
        else:
            print(f"  ❌ Login failed: {resp.json().get('message', resp.status_code)}")
            return None
    except Exception as e:
        print(f"  ❌ Login error: {e}")
        return None


def send_reading(heart_rate: int, oxygen_saturation: float,
                 patient_id: int = 0, url: str = API_URL,
                 token: Optional[str] = None) -> dict:
    """Send one vital signs reading to the backend."""

    # JWT mode — no patientId needed in body
    if token:
        payload = {
            "heartRate":        heart_rate,
            "oxygenSaturation": round(oxygen_saturation, 1),
        }
        headers = {
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {token}",
        }
    else:
        # Anonymous mode — patientId required
        payload = {
            "patientId":        patient_id,
            "heartRate":        heart_rate,
            "oxygenSaturation": round(oxygen_saturation, 1),
        }
        headers = {"Content-Type": "application/json"}

    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Sending → {json.dumps(payload)}")

    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=10)
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
    hr   = random.randint(62, 95)
    spo2 = round(random.uniform(96.0, 99.5), 1)
    return hr, spo2

def generate_emergency_high_hr() -> tuple[int, float]:
    hr   = random.randint(151, 180)
    spo2 = round(random.uniform(94.0, 97.0), 1)
    return hr, spo2

def generate_emergency_low_spo2() -> tuple[int, float]:
    hr   = random.randint(70, 100)
    spo2 = round(random.uniform(84.0, 89.5), 1)
    return hr, spo2

def generate_emergency_low_hr() -> tuple[int, float]:
    hr   = random.randint(25, 39)
    spo2 = round(random.uniform(94.0, 97.0), 1)
    return hr, spo2

SCENARIOS = {
    "normal":   generate_normal,
    "high_hr":  generate_emergency_high_hr,
    "low_spo2": generate_emergency_low_spo2,
    "low_hr":   generate_emergency_low_hr,
}


def main():
    parser = argparse.ArgumentParser(
        description="MediTrack Sensor Simulator — JWT or anonymous mode."
    )
    parser.add_argument("--url",      default=API_URL)
    parser.add_argument("--patient",  type=int, default=0,
                        help="Patient ID (anonymous mode). Omit to use JWT login.")
    parser.add_argument("--email",    default=None, help="Patient email for JWT login")
    parser.add_argument("--password", default=None, help="Patient password for JWT login")
    parser.add_argument("--hr",       type=int,   default=None)
    parser.add_argument("--spo2",     type=float, default=None)
    parser.add_argument("--scenario", choices=list(SCENARIOS.keys()), default=None)
    parser.add_argument("--loop",     action="store_true")
    parser.add_argument("--count",    type=int, default=None)
    parser.add_argument("--interval", type=int, default=INTERVAL)

    args = parser.parse_args()

    print("=" * 60)
    print("  MediTrack Sensor Simulator")
    print("=" * 60)

    token = None

    # JWT mode: login if no --patient given
    if args.patient == 0:
        email    = args.email    or input("  Patient email: ")
        password = args.password or getpass("  Password: ")
        token    = login(email, password)
        if not token:
            print("  Aborting — could not authenticate.")
            return
        mode_label = "JWT (patient from token)"
    else:
        mode_label = f"Anonymous (patient ID: {args.patient})"

    print(f"  Endpoint  : {args.url}")
    print(f"  Auth mode : {mode_label}")
    if args.loop:
        print(f"  Mode      : Loop every {args.interval}s")
        if args.count:
            print(f"  Count     : {args.count} readings")
    else:
        print("  Mode      : Single shot")
    print()

    count = 0
    while True:
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

        send_reading(hr, spo2,
                     patient_id=args.patient,
                     url=args.url,
                     token=token)
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
