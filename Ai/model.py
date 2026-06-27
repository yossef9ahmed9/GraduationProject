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

    # ── Hard override rules — MUST match .NET thresholds ──────────────────────
    # Mirrors: AutoEmergencyService.cs  HeartRateCriticalHigh=150, Low=40, SpO2=90
    #          VitalSignsService.cs     IsCritical() same values

    # CRITICAL overrides (same as AutoEmergencyService.cs)
    if spo2 < 90.0:
        tier = "CRITICAL"
        override_reason = f"SpO2 critically low at {spo2}% (threshold: 90%)"
    elif bpm >= 150:
        tier = "CRITICAL"
        override_reason = f"Heart rate critically high at {bpm} BPM (threshold: 150)"
    elif bpm <= 40:
        tier = "CRITICAL"
        override_reason = f"Heart rate critically low at {bpm} BPM (threshold: 40)"

    # WARNING overrides (below critical, above normal) — only if model said NORMAL
    elif spo2 < 95.0 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"SpO2 below optimal at {spo2}%"
    elif bpm >= 110 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"Heart rate elevated at {bpm} BPM"
    elif bpm <= 55 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"Heart rate low at {bpm} BPM"
    elif hrv_ms < 15 and tier == "NORMAL":
        tier = "WARNING"
        override_reason = f"HRV critically low at {hrv_ms} ms"

    cfg = TIER_CONFIG[tier]
    return {
        "tier"           : tier,
        "score"          : round(float(probs[2]) * 100, 1),
        "confidence"     : round(confidence * 100, 1),
        "action"         : cfg["action"],
        "message"        : cfg["message"],
        "alert"          : tier == "CRITICAL",   # CRITICAL فقط يطلق alert
        "override_reason": override_reason,
        "probabilities"  : {
            "normal"  : round(float(probs[0]) * 100, 1),
            "warning" : round(float(probs[1]) * 100, 1),
            "critical": round(float(probs[2]) * 100, 1),
        },
    }


# ─────────────────────────────────────────────────────────────────────────────
# Trend / Forecast
# ─────────────────────────────────────────────────────────────────────────────
def predict_trend(model, readings: list[dict], age: int, sex: int, hrv_ms: float) -> dict:
    """
    Emergency Risk Forecast.

    Core question: "Is this patient heading toward a critical emergency,
    and if so, how soon?"

    Output:
      emergency_risk_pct   : 0-100  — probability of hitting CRITICAL in ≤15 min
      emergency_in_min     : float | None — estimated minutes to CRITICAL threshold
      heading              : "TOWARD_EMERGENCY" | "AWAY_FROM_EMERGENCY" | "STABLE"
      current_tier         : NORMAL / WARNING / CRITICAL
      summary              : one plain-language sentence
      alert                : True if emergency is likely within 15 minutes
      confidence           : 0-100
    """
    if len(readings) < 3:
        raise ValueError("At least 3 readings are required.")

    # ── Sort oldest → newest ──────────────────────────────────────────────────
    sorted_readings = sorted(readings, key=lambda r: r["timestamp_offset_sec"], reverse=True)

    raw_bpm  = np.array([r["bpm"]  for r in sorted_readings], dtype=float)
    raw_spo2 = np.array([r["spo2"] for r in sorted_readings], dtype=float)
    offsets  = np.array([r["timestamp_offset_sec"] for r in sorted_readings], dtype=float)
    t_min    = (offsets.max() - offsets) / 60.0

    # ── Smoothing — 3-point moving average to reduce sensor noise ────────────
    win = min(3, len(raw_bpm))
    k   = np.ones(win) / win
    if len(raw_bpm) >= win:
        bpm_s  = np.convolve(raw_bpm,  k, mode="valid")
        spo2_s = np.convolve(raw_spo2, k, mode="valid")
        t_s    = t_min[win - 1:]
    else:
        bpm_s, spo2_s, t_s = raw_bpm, raw_spo2, t_min

    # ── Slope per minute ─────────────────────────────────────────────────────
    def slope(x, y):
        if len(x) < 2 or x.max() == x.min(): return 0.0
        return float(np.polyfit(x, y, 1)[0])

    bpm_slope  = slope(t_s, bpm_s)
    spo2_slope = slope(t_s, spo2_s)

    latest_bpm  = float(bpm_s[-1])
    latest_spo2 = float(spo2_s[-1])

    # ── Current state ─────────────────────────────────────────────────────────
    current     = predict_patient(model, {"bpm": latest_bpm, "spo2": latest_spo2,
                                          "hrv_ms": hrv_ms, "age": age, "sex": sex})
    current_tier = current["tier"]
    tier_order   = {"NORMAL": 0, "WARNING": 1, "CRITICAL": 2}

    # ── How far are we from the CRITICAL thresholds? ─────────────────────────
    # Critical zone: SpO2 < 90  OR  BPM >= 150  OR  BPM <= 40  (matches .NET)
    spo2_to_critical = max(0.0, latest_spo2 - 90.0)   # 0 = already there
    bpm_to_crit_high = max(0.0, 150.0 - latest_bpm)
    bpm_to_crit_low  = max(0.0, latest_bpm - 40.0)
    bpm_to_critical  = min(bpm_to_crit_high, bpm_to_crit_low)

    # Proximity score 0-100: 100 = at threshold, 0 = far away
    spo2_proximity = max(0.0, 100.0 - (spo2_to_critical / 15.0) * 100.0)
    bpm_proximity  = max(0.0, 100.0 - (bpm_to_critical  / 50.0) * 100.0)
    proximity_score = max(spo2_proximity, bpm_proximity)   # worst vital drives it

    # ── Is the trend heading toward or away from critical? ───────────────────
    # "Heading toward": SpO2 dropping OR BPM moving toward dangerous extremes
    spo2_heading_bad  = spo2_slope < -0.1    # SpO2 falling
    bpm_heading_bad   = (latest_bpm > 80  and bpm_slope >  0.5) or \
                        (latest_bpm < 60  and bpm_slope < -0.5)  # rising high or dropping low
    spo2_heading_good = spo2_slope >  0.08
    bpm_heading_good  = (latest_bpm > 80  and bpm_slope < -0.5) or \
                        (latest_bpm < 60  and bpm_slope >  0.5)

    heading_bad  = spo2_heading_bad  or bpm_heading_bad
    heading_good = spo2_heading_good or bpm_heading_good

    if heading_bad:
        heading = "TOWARD_EMERGENCY"
    elif heading_good:
        heading = "AWAY_FROM_EMERGENCY"
    else:
        heading = "STABLE"

    # ── Emergency risk % ─────────────────────────────────────────────────────
    # Base = proximity to critical threshold
    # Boost if trending toward it, reduce if trending away
    trend_multiplier = 1.4 if heading == "TOWARD_EMERGENCY" else \
                       0.6 if heading == "AWAY_FROM_EMERGENCY" else 1.0

    # Also use ML model's CRITICAL probability as a component
    critical_prob_pct = current["probabilities"]["critical"]  # 0-100

    # Weighted blend: 50% proximity-based + 50% model probability, scaled by trend
    emergency_risk_pct = min(100.0, (
        (proximity_score * 0.5 + critical_prob_pct * 0.5) * trend_multiplier
    ))
    emergency_risk_pct = round(emergency_risk_pct, 1)

    # ── Time to emergency threshold ──────────────────────────────────────────
    # بنحسب: لو الـ slope فضل زي ما هو، امتى هيوصل لـ threshold؟
    emergency_in_min = None

    # HR بيزيد → امتى هيوصل 150؟
    if bpm_slope > 0.1 and latest_bpm < 150:
        mins = (150 - latest_bpm) / bpm_slope
        if 0 < mins <= 120:
            emergency_in_min = round(mins, 1)
    # HR بيقل → امتى هيوصل 40؟
    elif bpm_slope < -0.1 and latest_bpm > 40:
        mins = (latest_bpm - 40) / abs(bpm_slope)
        if 0 < mins <= 120:
            emergency_in_min = round(mins, 1)

    # SpO2 بتقل → امتى هتوصل 90؟
    if spo2_slope < -0.05 and latest_spo2 > 90:
        mins = (latest_spo2 - 90) / abs(spo2_slope)
        if 0 < mins <= 120:
            # لو أسرع من الـ HR → استخدم SpO2
            if emergency_in_min is None or mins < emergency_in_min:
                emergency_in_min = round(mins, 1)

    # ── Alert: risk > 60% and heading toward emergency ────────────────────────
    alert = emergency_risk_pct >= 60 and heading == "TOWARD_EMERGENCY"

    # ── Plain-language summary ────────────────────────────────────────────────
    # لو المريض في critical بالفعل → مش محتاج توقع
    if current_tier == "CRITICAL":
        emergency_in_min = None
        heading          = "ALREADY_CRITICAL"
        summary          = f"🚨 Already critical — BPM {latest_bpm:.0f}, SpO₂ {latest_spo2:.1f}%."
        alert            = True
    elif emergency_in_min is not None:
        if emergency_in_min < 1:
            t_str = "less than 1 minute"
        elif emergency_in_min < 60:
            t_str = f"~{emergency_in_min:.0f} minutes"
        else:
            t_str = f"~{emergency_in_min/60:.1f} hours"
        heading = "TOWARD_EMERGENCY"
        summary = f"⚠️ Emergency expected in {t_str} if current trend continues."
    else:
        heading = "STABLE"
        summary = f"✅ No emergency predicted in the next 2 hours based on current readings."

    # ── Confidence ────────────────────────────────────────────────────────────
    window_min = float(t_min.max())
    n          = len(readings)
    noise_pen  = min(10.0, float(np.std(bpm_s)))
    confidence = min(95.0, 50.0 + n * 2.0 + window_min * 1.5 - noise_pen)

    return {
        # Core — what matters
        "emergency_risk_pct"  : emergency_risk_pct,
        "emergency_in_min"    : emergency_in_min,
        "heading"             : heading,
        "current_tier"        : current_tier,
        "summary"             : summary,
        "alert"               : alert,
        "confidence"          : round(confidence, 1),
        # Detail
        "bpm_slope"           : round(bpm_slope,  2),
        "spo2_slope"          : round(spo2_slope, 3),
        # Keep backward-compat fields so existing response schema still maps
        "trend_direction"     : heading,
        "forecast_tier_5min"  : predict_patient(model, {
            "bpm": float(np.clip(latest_bpm + bpm_slope * 5, 20, 300)),
            "spo2": float(np.clip(latest_spo2 + spo2_slope * 5, 50, 100)),
            "hrv_ms": hrv_ms, "age": age, "sex": sex})["tier"],
        "forecast_tier_10min" : predict_patient(model, {
            "bpm": float(np.clip(latest_bpm + bpm_slope * 10, 20, 300)),
            "spo2": float(np.clip(latest_spo2 + spo2_slope * 10, 50, 100)),
            "hrv_ms": hrv_ms, "age": age, "sex": sex})["tier"],
        "message"             : summary,
        "time_to_danger_min"  : emergency_in_min,
        "window_stats": {
            "bpm_mean" : round(float(np.mean(bpm_s)),  1),
            "bpm_max"  : round(float(np.max(bpm_s)),   1),
            "bpm_min"  : round(float(np.min(bpm_s)),   1),
            "bpm_std"  : round(float(np.std(bpm_s)),   2),
            "spo2_mean": round(float(np.mean(spo2_s)), 1),
            "spo2_min" : round(float(np.min(spo2_s)),  1),
        },
    }
    """
    Analyse a time-series of BPM + SpO2 readings and forecast near-future risk.

    Improvements over v1:
    - Moving-average smoothing to handle real sensor noise
    - Rich feature set: mean, max, min, slope, std — not slope alone
    - Direction logic uses current_tier cap (can't IMPROVE above CRITICAL)
    - time_to_danger computed on smoothed values

    readings: list of dicts {bpm, spo2, timestamp_offset_sec} newest-first.
    """
    if len(readings) < 3:
        raise ValueError("At least 3 readings are required for trend analysis.")

    # ── Sort oldest → newest ──────────────────────────────────────────────────
    sorted_readings = sorted(readings, key=lambda r: r["timestamp_offset_sec"], reverse=True)

    raw_bpm  = np.array([r["bpm"]  for r in sorted_readings], dtype=float)
    raw_spo2 = np.array([r["spo2"] for r in sorted_readings], dtype=float)
    offsets  = np.array([r["timestamp_offset_sec"] for r in sorted_readings], dtype=float)
    t_min    = (offsets.max() - offsets) / 60.0   # minutes from oldest reading

    # ── Smoothing — moving average to reduce sensor noise ────────────────────
    smooth_window = min(3, len(raw_bpm))
    if len(raw_bpm) >= smooth_window:
        kernel    = np.ones(smooth_window) / smooth_window
        bpm_vals  = np.convolve(raw_bpm,  kernel, mode="valid")
        spo2_vals = np.convolve(raw_spo2, kernel, mode="valid")
        t_smooth  = t_min[smooth_window - 1:]
    else:
        bpm_vals  = raw_bpm
        spo2_vals = raw_spo2
        t_smooth  = t_min

    # ── Slope (change per minute) ────────────────────────────────────────────
    def calc_slope(x, y):
        if len(x) < 2 or x.max() == x.min():
            return 0.0
        return float(np.polyfit(x, y, 1)[0])

    bpm_slope  = calc_slope(t_smooth, bpm_vals)
    spo2_slope = calc_slope(t_smooth, spo2_vals)

    # ── Rich features from the window ────────────────────────────────────────
    bpm_mean  = float(np.mean(bpm_vals))
    bpm_max   = float(np.max(bpm_vals))
    bpm_min   = float(np.min(bpm_vals))
    bpm_std   = float(np.std(bpm_vals))
    spo2_mean = float(np.mean(spo2_vals))
    spo2_min  = float(np.min(spo2_vals))   # worst-case SpO2 in window

    # Use the latest smoothed value for current classification
    latest_bpm  = float(bpm_vals[-1])
    latest_spo2 = float(spo2_vals[-1])

    # ── Classify current state ───────────────────────────────────────────────
    current = predict_patient(model, {
        "bpm": latest_bpm, "spo2": latest_spo2,
        "hrv_ms": hrv_ms, "age": age, "sex": sex,
    })
    tier_order  = {"NORMAL": 0, "WARNING": 1, "CRITICAL": 2}
    current_ord = tier_order[current["tier"]]

    # ── Forecast values at +5 min and +10 min ───────────────────────────────
    def forecast_values(minutes: float):
        f_bpm  = float(np.clip(latest_bpm  + bpm_slope  * minutes, 20,  300))
        f_spo2 = float(np.clip(latest_spo2 + spo2_slope * minutes, 50, 100))
        return f_bpm, f_spo2

    bpm_5,  spo2_5  = forecast_values(5)
    bpm_10, spo2_10 = forecast_values(10)

    tier_5  = predict_patient(model, {"bpm": bpm_5,  "spo2": spo2_5,
                                      "hrv_ms": hrv_ms, "age": age, "sex": sex})["tier"]
    tier_10 = predict_patient(model, {"bpm": bpm_10, "spo2": spo2_10,
                                      "hrv_ms": hrv_ms, "age": age, "sex": sex})["tier"]
    future_ord = tier_order[tier_10]

    # ── Direction logic ──────────────────────────────────────────────────────
    # Key fix: if currently CRITICAL, readings going higher is NOT "IMPROVING"
    # — it's still WORSENING or at best STABLE.
    # Also use tighter slope thresholds for real sensor data.

    if current_ord == tier_order["CRITICAL"]:
        # Already critical — can only STABLE or WORSENING within this tier
        # "improving" only if forecast drops to WARNING or below
        if future_ord < current_ord:
            direction = "IMPROVING"
        elif spo2_slope < -0.1 or bpm_slope > 0.5:
            direction = "WORSENING"
        else:
            direction = "STABLE"

    elif future_ord > current_ord:
        direction = "WORSENING"

    elif future_ord < current_ord:
        direction = "IMPROVING"

    else:
        # Same tier — use slopes with sensor-noise-aware thresholds
        spo2_bad  = spo2_slope < -0.1   # falling > 0.1 %/min
        bpm_bad   = bpm_slope  >  0.5   # rising  > 0.5 bpm/min
        spo2_good = spo2_slope >  0.08  # rising  > 0.08 %/min
        bpm_good  = bpm_slope  < -0.4   # falling > 0.4 bpm/min
        # Also check window stats: high std = unstable
        unstable  = bpm_std > 8 or (bpm_max - bpm_min) > 20

        if spo2_bad or bpm_bad or unstable:
            direction = "WORSENING"
        elif spo2_good or bpm_good:
            direction = "IMPROVING"
        else:
            direction = "STABLE"

    # ── Alert ────────────────────────────────────────────────────────────────
    alert = direction == "WORSENING" and future_ord >= 1

    # ── Time-to-threshold ────────────────────────────────────────────────────
    def mins_to_cross(val, slope_val, threshold, direction_cross="below"):
        if slope_val == 0:
            return None
        if direction_cross == "below":
            if val <= threshold: return 0.0
            if slope_val >= 0:   return None
            return (val - threshold) / abs(slope_val)
        else:
            if val >= threshold: return 0.0
            if slope_val <= 0:   return None
            return (threshold - val) / slope_val

    candidates = [t for t in [
        mins_to_cross(latest_spo2, spo2_slope, 95.0, "below"),
        mins_to_cross(latest_spo2, spo2_slope, 90.0, "below"),
        mins_to_cross(latest_bpm,  bpm_slope,  110.0, "above"),
        mins_to_cross(latest_bpm,  bpm_slope,  150.0, "above"),
    ] if t is not None and t >= 0]
    time_to_danger_min = round(min(candidates), 1) if candidates else None

    # ── Message ──────────────────────────────────────────────────────────────
    bpm_txt  = f"BPM {'↑' if bpm_slope > 0 else '↓'} {abs(bpm_slope):.1f}/min"
    spo2_txt = f"SpO₂ {'↑' if spo2_slope > 0 else '↓'} {abs(spo2_slope):.2f}%/min"

    if direction == "WORSENING":
        if time_to_danger_min is not None and time_to_danger_min <= 30:
            danger_str = (f"{time_to_danger_min:.0f} min" if time_to_danger_min >= 1
                          else "less than 1 min")
            msg = (f"⚠ Deteriorating — {bpm_txt}, {spo2_txt}. "
                   f"Danger threshold in ~{danger_str}.")
        else:
            msg = (f"⚠ Deteriorating — {bpm_txt}, {spo2_txt}. "
                   f"Current BPM {latest_bpm:.0f}, SpO₂ {latest_spo2:.1f}%.")
    elif direction == "IMPROVING":
        msg = (f"✓ Improving — {bpm_txt}, {spo2_txt}. "
               f"Current BPM {latest_bpm:.0f}, SpO₂ {latest_spo2:.1f}%.")
    else:
        msg = (f"Stable — {bpm_txt}, {spo2_txt}. "
               f"Current BPM {latest_bpm:.0f}, SpO₂ {latest_spo2:.1f}%.")

    # ── Confidence: more readings + longer window + low noise = higher ───────
    window_min = float(t_min.max())
    n          = len(readings)
    noise_pen  = min(10.0, bpm_std)           # penalise noisy signals
    confidence = min(95.0, 50.0 + n * 2.0 + window_min * 1.5 - noise_pen)

    return {
        "current_tier"       : current["tier"],
        "trend_direction"    : direction,
        "bpm_slope"          : round(bpm_slope,  2),
        "spo2_slope"         : round(spo2_slope, 3),
        "forecast_tier_5min" : tier_5,
        "forecast_tier_10min": tier_10,
        "alert"              : alert,
        "message"            : msg,
        "confidence"         : round(confidence, 1),
        "time_to_danger_min" : time_to_danger_min,
        # extra window stats — useful for debugging
        "window_stats": {
            "bpm_mean" : round(bpm_mean,  1),
            "bpm_max"  : round(bpm_max,   1),
            "bpm_min"  : round(bpm_min,   1),
            "bpm_std"  : round(bpm_std,   2),
            "spo2_mean": round(spo2_mean, 1),
            "spo2_min" : round(spo2_min,  1),
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
