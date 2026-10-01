# 🏥 MediTrack — Smart Healthcare Monitoring System

> A full-stack graduation project that monitors chronic patients in real time using a wearable pulse oximeter sensor, an AI-powered risk engine, and a cross-platform mobile app — so patients are never truly alone.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [The Problem We Solve](#-the-problem-we-solve)
- [How It Works](#-how-it-works)
- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Project Structure](#-project-structure)
- [Tech Stack](#-tech-stack)
- [User Roles](#-user-roles)
- [Emergency Flow](#-emergency-flow)
- [AI Model](#-ai-model)
- [Real-Time Chat](#-real-time-chat)
- [Getting Started](#-getting-started)
- [Demo Video](#-demo-video)

---

## 🌟 Overview

**MediTrack** is an end-to-end remote patient monitoring platform built for chronic disease patients. It combines an ESP32 microcontroller with a MAX30102 pulse oximeter sensor, a .NET backend, a Python AI service, and a Flutter mobile app to deliver real-time health monitoring, intelligent risk assessment, and automated emergency dispatch — all without the patient needing to do anything.

---

## 🤔 The Problem We Solve

Millions of chronic disease patients — heart failure, COPD, diabetes — live alone or far from medical care. A critical event can happen at 2 AM when no one is watching. By the time someone notices, it may be too late.

**MediTrack solves this by:**

- Monitoring the patient **continuously**, 24/7, through a wearable sensor
- Using **AI** to decide if the situation is normal, a warning, or life-threatening
- **Automatically dispatching the nearest ambulance** the moment a critical reading is detected — no button press needed
- Keeping doctors, family members, and the patient all informed in real time

---

## ⚙️ How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  ESP32 + MAX30102 Sensor                                        │
│  Reads: Heart Rate (BPM) + Blood Oxygen (SpO₂)                 │
│  Sends data every 30 seconds via WiFi                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │  POST /api/vitalsigns/sensor
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  ASP.NET Core Backend                                           │
│  • Saves vital signs to SQL Server                             │
│  • Calls the AI service for risk assessment                    │
│  • Triggers emergency dispatch if CRITICAL                     │
│  • Sends push notifications (FCM) to all stakeholders          │
│  • Real-time chat via SignalR                                   │
└──────────┬──────────────────────────────┬───────────────────────┘
           │  HTTP                        │  SignalR / FCM
           ▼                              ▼
┌──────────────────────┐     ┌────────────────────────────────────┐
│  Python FastAPI (AI) │     │  Flutter Mobile App                │
│  GradientBoosting    │     │  Patient / Doctor / Relative /     │
│  NORMAL / WARNING /  │     │  Ambulance / Lab / Admin           │
│  CRITICAL            │     │                                    │
└──────────────────────┘     └────────────────────────────────────┘
```

---

## ✨ Key Features

### 🚨 Automated Emergency System
- Sensor data is evaluated by AI on every reading
- If **CRITICAL**: the system finds the 3 nearest available ambulances using GPS + Haversine distance
- All 3 receive a dispatch request simultaneously — first to accept wins, others are cancelled
- Doctors and relatives receive instant push notifications
- If the next reading returns to normal, pending dispatches are **automatically cancelled**

### 🤖 AI Risk Assessment
- Trained GradientBoosting model on MAX30102 sensor features
- Input: Heart Rate, SpO₂, HRV, Age, Sex
- Output: **NORMAL / WARNING / CRITICAL** + recommended action
- Hard override rules ensure critical thresholds (SpO₂ < 90%, HR ≥ 150) are always caught

### 💬 Real-Time Chat
- Doctors and patients can message each other instantly via **SignalR WebSockets**
- **FCM push notifications** wake up the app when it's closed
- Optimistic message bubbles, read receipts, delete for me / delete for everyone

### 🔬 Lab Test Management
- Patients request tests from registered labs
- Labs upload results (PDF / image)
- **Tesseract OCR** automatically extracts text from uploaded documents
- Doctors see results directly in the patient file

### 📍 Live GPS Tracking
- Ambulance location updates every 10 seconds during an active dispatch
- Patient and doctor can track the ambulance on a live map
- Ambulance driver gets turn-by-turn navigation to the patient

### 📊 Vitals Dashboard
- Full history of vital signs with charts (HR + SpO₂ trends)
- Status badges: 🟢 Normal / 🟡 Warning / 🔴 Emergency
- Emergency banner appears automatically when `emergencyStatus = true`

### 👨‍👩‍👧 Family Access
- Relatives can request to link to a patient
- Once approved, they see live vitals, emergency status, and can chat

### ⭐ Ratings
- Patients rate doctors and labs (1–5 stars)
- Helps maintain quality of care across the platform

---

## 🏗️ System Architecture

### Three-Tier Design

| Layer | Technology | Responsibility |
|---|---|---|
| **Mobile App** | Flutter (Dart) | UI for all 6 user roles |
| **Backend API** | ASP.NET Core 8 | Business logic, auth, data, real-time |
| **AI Service** | Python FastAPI | Risk classification, model inference |
| **Database** | SQL Server + EF Core | Persistent storage |
| **Push** | Firebase FCM | Background notifications |
| **Real-time** | SignalR | Live chat and status updates |
| **Hardware** | ESP32 + MAX30102 | Continuous vital signs sensing |

---

## 📁 Project Structure

```
GraduationProject/
│
├── 📂 GraduationProject/          # ASP.NET Core Backend
│   ├── Controllers/               # 22 API controllers
│   │   ├── AuthController.cs      # Login, register, JWT, password reset
│   │   ├── VitalSignsController.cs# Vitals CRUD + sensor endpoint
│   │   ├── EmergencyDispatchesController.cs
│   │   ├── ChatController.cs      # Chat history, conversations
│   │   ├── HeartRiskController.cs # AI predictions
│   │   ├── MedicalTestsController.cs
│   │   ├── OcrController.cs       # Tesseract OCR
│   │   ├── LocationController.cs  # GPS tracking
│   │   └── ...
│   ├── Entities/                  # 17 database entities
│   │   ├── Patient.cs
│   │   ├── VitalSigns.cs          # Core vital data + emergencyStatus
│   │   ├── EmergencyDispatch.cs   # Ambulance dispatch records
│   │   ├── ChatMessage.cs         # Per-user soft delete
│   │   ├── Ambulance.cs           # GPS + availability
│   │   └── ...
│   ├── Services/                  # Business logic layer
│   │   ├── VitalSignsService.cs   # AI call + emergency trigger
│   │   ├── AutoEmergencyService.cs# Haversine nearest ambulance
│   │   ├── HeartRiskService.cs    # Python AI client
│   │   ├── FcmService.cs          # Firebase push notifications
│   │   └── ...
│   ├── Hubs/
│   │   └── ChatHub.cs             # SignalR real-time chat
│   ├── Contracts/                 # Request/Response DTOs
│   ├── Presistence/               # AppDbContext (EF Core)
│   ├── Program.cs                 # App startup + SignalR + CORS
│   └── DependencyInjection.cs     # Service registration
│
├── 📂 meditrack/                  # Flutter Mobile App
│   └── lib/
│       ├── models/
│       │   └── models.dart        # 25+ model classes mirroring backend
│       ├── services/
│       │   ├── api_service.dart   # All HTTP calls (singleton)
│       │   ├── app_provider.dart  # Global state (Provider pattern)
│       │   ├── auth_provider.dart # JWT + user session
│       │   ├── chat_service.dart  # SignalR client
│       │   ├── fcm_service.dart   # Firebase push handler
│       │   └── location_service.dart # GPS for ambulance
│       ├── screens/
│       │   ├── home_screen.dart   # Main shell with emergency vignette
│       │   ├── chat_screen.dart   # Real-time chat UI
│       │   └── pages/
│       │       ├── vitals_page.dart      # Charts + status badges
│       │       ├── dispatch_tracking_page.dart # Live ambulance map
│       │       ├── ambulance_navigation_page.dart
│       │       ├── patient_file_page.dart
│       │       ├── tests_page.dart
│       │       └── ...            # 24 total pages
│       ├── theme/
│       │   └── app_theme.dart     # Dark / Light theme colors
│       └── widgets/
│           └── common_widgets.dart # Reusable UI components
│
├── 📂 Ai/                         # Python FastAPI AI Service
│   ├── main.py                    # FastAPI app + endpoints
│   ├── model.py                   # GradientBoosting model + training
│   ├── schemas.py                 # Pydantic request/response schemas
│   ├── max30102_dataset.csv       # Training data (2000 samples)
│   ├── max30102_model.pkl         # Saved trained model
│   ├── requirements.txt           # Python dependencies
│   ├── arduino_sensor/
│   │   └── arduino_sensor.ino     # Full ESP32 firmware (WiFi provisioning)
│   ├── arduino_sensor_test/
│   │   └── arduino_sensor_test.ino# Simple test sketch
│   └── i2c_scan/
│       └── i2c_scan.ino           # I2C device scanner utility
│
└── 📄 README.md
```

---

## 🛠️ Tech Stack

### Backend — `GraduationProject/`
| Technology | Version | Purpose |
|---|---|---|
| ASP.NET Core | 8.0 | Web API framework |
| Entity Framework Core | Latest | ORM + Code First migrations |
| SQL Server | — | Primary database |
| ASP.NET Identity | — | User management + roles |
| JWT Bearer | — | Stateless authentication |
| SignalR | Built-in | Real-time WebSocket chat |
| Firebase Admin SDK | Latest | FCM push notifications |
| Tesseract OCR | — | Medical document text extraction |
| Mapster | — | Object mapping |
| FluentValidation | — | Request validation |

### AI Service — `Ai/`
| Technology | Purpose |
|---|---|
| Python 3.x | Runtime |
| FastAPI | REST API framework |
| scikit-learn | GradientBoosting model |
| numpy / pandas | Data processing |
| joblib | Model serialization |
| Pydantic | Schema validation |

### Mobile App — `meditrack/`
| Package | Purpose |
|---|---|
| Flutter 3.x | Cross-platform mobile framework |
| Provider | State management |
| `signalr_netcore ^1.4.4` | SignalR WebSocket client |
| `firebase_messaging ^15.1.3` | FCM push notifications |
| `fl_chart` | Vital signs charts |
| `flutter_map` + `latlong2` | Live GPS map |
| `geolocator` | Device GPS |
| `http` | REST API calls |
| `jwt_decoder` | Token parsing |

### Hardware
| Component | Detail |
|---|---|
| Microcontroller | ESP32-C3 |
| Sensor | MAX30102 (Heart Rate + SpO₂) |
| Wiring | SDA → GPIO 8, SCL → GPIO 9, VCC → 3.3V |
| Protocol | HTTP POST every 30 seconds |
| Provisioning | WiFi AP mode (`MediTrack-Setup`) |

---

## 👥 User Roles

| Role | Who | What They Can Do |
|---|---|---|
| 🧑‍⚕️ **Patient** | The monitored person | View own vitals, chat with doctor, request lab tests, manage sensor |
| 👨‍⚕️ **Doctor** | Treating physician | View assigned patients, review vitals & files, chat, manage follow-ups |
| 👨‍👩‍👧 **Relative** | Family member | View patient vitals & emergency status, chat |
| 🚑 **Ambulance** | Driver | Accept/reject dispatches, GPS navigation to patient |
| 🔬 **Lab** | Medical laboratory | Receive test requests, upload results |
| 🔧 **Admin** | System administrator | Full access to all data and management |

---

## 🚨 Emergency Flow

```
1. ESP32 reads HR + SpO₂ every 30 seconds
          ↓
2. POST /api/vitalsigns/sensor (no auth required)
          ↓
3. Backend calls Python AI → CRITICAL / WARNING / NORMAL
          ↓  (if AI offline → fallback: HR≥150 OR SpO₂<90 → CRITICAL)
          ↓
4. ── CRITICAL ──────────────────────────────────────────────────
   • EmergencyStatus = true, Patient.IsInEmergency = true
   • Find top 3 nearest ambulances (GPS + Haversine distance)
   • Create Pending dispatch for each
   • FCM push → ambulance app, doctor app, relative app
   • Ambulance accepts → Status = OnTheWay → others cancelled
   • Live GPS tracking begins (updates every 10s)
          ↓
5. ── WARNING ───────────────────────────────────────────────────
   • No dispatch, no emergency banner
   • SnackBar notification to doctor + relative only
          ↓
6. ── Next reading is NORMAL (was in emergency) ─────────────────
   • Cancel all Pending dispatches
   • Notify OnTheWay ambulances: "patient stabilised"
   • Patient.IsInEmergency = false
   • FCM push: "Vitals Normal" to doctor + relative
```

---

## 🤖 AI Model

**Algorithm:** Gradient Boosting Classifier (scikit-learn)

**Input Features:**
```
bpm        → Heart rate in BPM
spo2       → Blood oxygen saturation (%)
hrv_ms     → Heart rate variability (ms)
age        → Patient age
sex        → 0 = female, 1 = male
+ 8 engineered features (ratios, flags, risk indicators)
```

**Output:**
```
NORMAL   → No action needed
WARNING  → See a doctor within 24-48 hours
CRITICAL → Emergency services alerted
```

**Performance:**
```
Test Accuracy : 83%
CV Accuracy   : 85.5%
AUC (macro)   : 93.7%
Training set  : 2,000 synthetic samples
```

**Safety Net — Hard Override Rules** (always applied regardless of model):
```
SpO₂ < 90%  → Always CRITICAL
HR ≥ 150    → Always CRITICAL
HR ≤ 40     → Always CRITICAL
```

**Endpoints:**
```
POST /predict         → Single reading → risk tier
POST /predict/batch   → Multiple readings at once
POST /predict/window  → 30-second averaged window (recommended for hardware)
GET  /model/info      → Model metadata and metrics
GET  /model/retrain   → Retrain from dataset
GET  /health          → Service status
```

---

## 💬 Real-Time Chat

Two technologies work together to cover all scenarios:

| Scenario | Technology |
|---|---|
| App is open | **SignalR** WebSocket — instant delivery |
| App is in background | **FCM** push notification — wakes the app |
| App is closed | **FCM** push notification — shown as system notification |

**JWT Authentication with SignalR:**
SignalR cannot send JWT in headers like regular HTTP. The token is passed as a query parameter `?access_token=TOKEN` and extracted by the backend's `OnMessageReceived` event.

**Message delivery flow:**
```
User types message → optimistic bubble (⏱️ pending)
      ↓ SignalR invoke
ChatHub.SendMessage()
  → Save to DB
  → Clients.Group(receiverEmail) → ReceiveMessage  (live delivery)
  → Clients.Caller → ReceiveMessage (confirm sent ✓✓)
  → FCM push if receiver offline
```

---

## 🚀 Getting Started

### Prerequisites
- .NET 8 SDK
- SQL Server
- Python 3.9+
- Flutter 3.x
- Arduino IDE (for ESP32 firmware)
- Firebase project (for FCM)

### 1. Backend Setup
```bash
cd GraduationProject

# Update connection string in appsettings.json
# "DefaultConnection": "Server=...;Database=MediTrack;..."

# Run migrations
dotnet ef database update

# Start the server
dotnet run --urls "http://0.0.0.0:5098"
```

### 2. AI Service Setup
```bash
cd Ai

pip install -r requirements.txt

# Start the AI server
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 3. Mobile App Setup
```bash
cd meditrack

# Update the IP address in:
# lib/services/api_service.dart  → const String _base
# lib/services/chat_service.dart → const String _hubUrl / _base

flutter pub get
flutter run
```

### 4. ESP32 Firmware
1. Open `Ai/arduino_sensor/arduino_sensor.ino` in Arduino IDE
2. Install libraries: `SparkFun MAX3010x`, `ArduinoJson`, `ESP32`
3. Flash to ESP32-C3
4. On first boot, connect to WiFi `MediTrack-Setup`
5. POST to `http://192.168.4.1/provision`:
```json
{
  "ssid": "YourWiFiName",
  "password": "YourWiFiPassword",
  "patientId": 1
}
```

### 5. Firebase Setup
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Download `google-services.json` → place in `meditrack/android/app/`
3. Generate Admin SDK key → save as `GraduationProject/firebase-adminsdk.json`
4. Add to `appsettings.json`:
```json
"Firebase": {
  "CredentialPath": "firebase-adminsdk.json"
}
```

---

## 📸 Hardware Wiring

```
MAX30102        ESP32-C3
────────        ────────
VCC      →      3.3V
GND      →      GND
SDA      →      GPIO 8
SCL      →      GPIO 9
```

> ⚠️ Use **3.3V** not 5V. The MAX30102 operates at 1.8V–3.3V logic.

---

## 🎬 Demo Video

A full walkthrough of the application — sensor readings, emergency dispatch, real-time chat, lab tests, and more.

**[▶️ Watch Demo Video](Testing%20Video/QuickOverView.mp4)**

> The video is located in the `Testing Video/` folder in this repository.

---

## 👨‍💻 Built With ❤️ as a Graduation Project

> *"We didn't just build an app — we built a safety net for patients who live far from care."*
