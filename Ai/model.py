"""
model.py — MAX30102 Pulse Sensor AI Model
==========================================
Features used (all directly from MAX30102 sensor + patient profile):
  bpm     → heart rate in beats per minute
  spo2    → blood oxygen saturation (%)
  hrv_ms  → heart rate variability in milliseconds (from IBI)
  age     → patient age (entered once at setup)
  sex     → 1 = male, 0 = female (entered once at setup)

Labels:
  0 → NORMAL    (no action needed)
  1 → WARNING   (see a doctor)
  2 → CRITICAL  (call ambulance)
"""

import os
import joblib
import warnings
import numpy as np
import pandas as pd

from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler, label_binarize
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, roc_auc_score, accuracy_score

warnings.filterwarnings("ignore")
np.random.seed(42)

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "max30102_model.pkl")
CSV_PATH   = os.path.join(BASE_DIR, "max30102_dataset.csv")

FEATURES = [
    "bpm", "spo2", "hrv_ms", "age", "sex",
    "bpm_spo2_ratio", "age_hrv_ratio",
    "tachycardia", "bradycardia",
    "hypoxia_mild", "hypoxia_severe",
    "low_hrv", "age_risk",
]


# ─────────────────────────────────────────────────────────────────────────────
# Feature Engineering
# ─────────────────────────────────────────────────────────────────────────────
def build_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["bpm_spo2_ratio"] = df["bpm"] / (df["spo2"] + 1e-6)
    df["age_hrv_ratio"]  = df["age"] / (df["hrv_ms"] + 1e-6)
    df["tachycardia"]    = (df["bpm"] > 100).astype(int)
    df["bradycardia"]    = (df["bpm"] < 55).astype(int)
    df["hypoxia_mild"]   = (df["spo2"] < 95).astype(int)
    df["hypoxia_severe"] = (df["spo2"] < 90).astype(int)
    df["low_hrv"]        = (df["hrv_ms"] < 20).astype(int)
    df["age_risk"]       = (df["age"] > 60).astype(int)
    return df


# ─────────────────────────────────────────────────────────────────────────────
# Dataset
# ─────────────────────────────────────────────────────────────────────────────
def generate_dataset(n: int = 2000) -> pd.DataFrame:
    np.random.seed(42)
    age = np.random.normal(52, 15, n).clip(18, 90).astype(int)
    sex = np.random.choice([0, 1], n, p=[0.45, 0.55])
    pop = np.random.choice(["normal", "mild", "high"], n, p=[0.60, 0.25, 0.15])

    bpm = np.where(pop == "normal",
            np.random.normal(72, 10, n).clip(55, 100),
            np.where(pop == "mild",
                np.random.normal(95, 15, n).clip(55, 140),
                np.random.normal(135, 25, n).clip(60, 185)
            )).round(1)

    spo2 = np.where(pop == "normal",
            np.random.normal(98.0, 0.8, n).clip(95, 100),
            np.where(pop == "mild",
                np.random.normal(95.5, 1.5, n).clip(90, 99),
                np.random.normal(89.0, 3.5, n).clip(75, 96)
            )).round(1)

    hrv = np.where(pop == "normal",
            np.random.normal(62, 15, n).clip(30, 110),
            np.where(pop == "mild",
                np.random.normal(35, 12, n).clip(10, 70),
                np.random.normal(15,  7, n).clip(3,  40)
            )).round(1)

    age_factor = np.where(age > 65, 1.3, np.where(age > 50, 1.1, 1.0))
    risk = (
        np.where(pop == "normal", np.random.uniform(0.00, 0.22, n),
        np.where(pop == "mild",   np.random.uniform(0.18, 0.58, n),
                                  np.random.uniform(0.50, 1.00, n)))
        * age_factor + np.random.normal(0, 0.04, n)
    ).clip(0, 1)

    labels = np.where(risk >= 0.60, 2, np.where(risk >= 0.28, 1, 0))

    df = pd.DataFrame({
        "bpm": bpm, "spo2": spo2, "hrv_ms": hrv,
        "age": age, "sex": sex,
        "risk_score": risk.round(3), "label": labels,
    })
    df.to_csv(CSV_PATH, index=False)
    return df


def load_dataset() -> pd.DataFrame:
    if os.path.exists(CSV_PATH):
        return pd.read_csv(CSV_PATH)
    print("  Dataset not found — generating ...")
    return generate_dataset()


# ─────────────────────────────────────────────────────────────────────────────
# Training
# ─────────────────────────────────────────────────────────────────────────────
def train_model() -> tuple:
    df = load_dataset()
    df = build_features(df)

    X = df[FEATURES]
    y = df["label"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("model",  GradientBoostingClassifier(
            n_estimators=300,
            learning_rate=0.05,
            max_depth=4,
            subsample=0.8,
            random_state=42,
        ))
    ])

    cv     = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_acc = cross_val_score(pipeline, X_train, y_train, cv=cv, scoring="accuracy").mean()

    pipeline.fit(X_train, y_train)

    y_pred  = pipeline.predict(X_test)
    y_prob  = pipeline.predict_proba(X_test)
    y_bin   = label_binarize(y_test, classes=[0, 1, 2])
    test_auc = roc_auc_score(y_bin, y_prob, multi_class="ovr", average="macro")
    test_acc = accuracy_score(y_test, y_pred)

    print("\n  Classification Report:")
    print(classification_report(y_test, y_pred,
          target_names=["Normal", "Warning", "Critical"]))

    meta = {
        "model_name"    : "GradientBoosting (MAX30102)",
        "test_auc"      : round(test_auc, 4),
        "test_accuracy" : round(test_acc, 4),
        "cv_accuracy"   : round(cv_acc,   4),
        "n_features"    : len(FEATURES),
        "features"      : FEATURES,
        "trained_on"    : len(df),
        "classes"       : ["NORMAL", "WARNING", "CRITICAL"],
        "model_path"    : MODEL_PATH,
        "sensor"        : "MAX30102",
    }

    joblib.dump({"model": pipeline, "meta": meta}, MODEL_PATH)
    print(f"  Saved to {MODEL_PATH}")
    print(f"  AUC={meta['test_auc']}  Acc={meta['test_accuracy']}")
    return pipeline, meta


# ─────────────────────────────────────────────────────────────────────────────
# Load or Train
# ─────────────────────────────────────────────────────────────────────────────
def load_or_train_model(force_retrain: bool = False) -> tuple:
    if not force_retrain and os.path.exists(MODEL_PATH):
        print(f"  Loading saved model from {MODEL_PATH}")
        obj = joblib.load(MODEL_PATH)
        if "meta" in obj:
            return obj["model"], obj["meta"]
    print("  Training model from scratch ...")
    return train_model()


# ─────────────────────────────────────────────────────────────────────────────
# Risk Classification
# ─────────────────────────────────────────────────────────────────────────────
TIER_CONFIG = {
    "NORMAL": {
        "action" : "No action needed — you are fine.",
        "message": (
            "All readings are within healthy range. "
            "Heart rate, oxygen levels, and HRV look good. "
            "Continue your normal activities and stay hydrated."
        ),
        "alert": False,
    },
    "WARNING": {
        "action" : "Schedule a doctor visit within 24-48 hours.",
        "message": (
            "Some readings are outside the optimal range. "
            "This is not an emergency, but you should see a doctor soon. "
            "Avoid strenuous exercise, rest, and keep the sensor on "
            "to monitor your readings every 15 minutes."
        ),
        "alert": False,
    },
    "CRITICAL": {
        "action" : "AMBULANCE ALERT — calling emergency services now.",
        "message": (
            "Vitals indicate a potentially life-threatening cardiac event. "
            "Emergency services have been alerted. Lie down, stay calm, "
            "loosen tight clothing, and do not eat or drink. Help is on the way."
        ),
        "alert": True,
    },
}


def classify_risk(probs: np.ndarray, bpm: float, spo2: float, hrv_ms: float) -> dict:
    predicted_class = int(np.argmax(probs))
    confidence      = float(np.max(probs))
    tiers           = ["NORMAL", "WARNING", "CRITICAL"]
    tier            = tiers[predicted_class]
    override_reason = None

    # Hard override rules — extreme sensor readings always win
    if spo2 < 85:
        tier = "CRITICAL"
        override_reason = f"SpO2 critically low at {spo2}% (threshold: 85%)"
    elif spo2 < 90 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"SpO2 below safe threshold at {spo2}%"

    if bpm > 170:
        tier = "CRITICAL"
        override_reason = f"Heart rate dangerously high at {bpm} BPM"
    elif bpm < 35:
        tier = "CRITICAL"
        override_reason = f"Heart rate dangerously low at {bpm} BPM"
    elif (bpm > 130 or bpm < 45) and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"Heart rate outside safe range at {bpm} BPM"

    if hrv_ms < 8 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"HRV critically low at {hrv_ms} ms — possible arrhythmia"

    cfg = TIER_CONFIG[tier]
    return {
        "tier"           : tier,
        "score"          : round(float(probs[2]) * 100, 1),
        "confidence"     : round(confidence * 100, 1),
        "action"         : cfg["action"],
        "message"        : cfg["message"],
        "alert"          : cfg["alert"],
        "override_reason": override_reason,
        "probabilities"  : {
            "normal"  : round(float(probs[0]) * 100, 1),
            "warning" : round(float(probs[1]) * 100, 1),
            "critical": round(float(probs[2]) * 100, 1),
        },
    }


# ─────────────────────────────────────────────────────────────────────────────
# Prediction Entry Point
# ─────────────────────────────────────────────────────────────────────────────
def predict_patient(model, data: dict) -> dict:
    bpm    = float(data["bpm"])
    spo2   = float(data["spo2"])
    hrv_ms = float(data["hrv_ms"])

    row = pd.DataFrame([{
        "bpm"    : bpm,
        "spo2"   : spo2,
        "hrv_ms" : hrv_ms,
        "age"    : int(data["age"]),
        "sex"    : int(data.get("sex", 1)),
    }])
    row   = build_features(row)
    probs = model.predict_proba(row[FEATURES])[0]
    return classify_risk(probs, bpm, spo2, hrv_ms)
