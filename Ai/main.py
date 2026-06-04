"""
main.py — MAX30102 Heart Risk FastAPI Application
==================================================
Designed specifically for the MAX30102 pulse oximeter sensor.

Endpoints:
  GET  /                   → API overview & available routes
  GET  /health             → server + model status
  POST /predict            → single sensor reading → risk assessment
  POST /predict/batch      → multiple readings at once
  POST /predict/window     → 30-second averaged window (recommended)
  GET  /model/info         → model metadata & performance
  GET  /model/retrain      → retrain model from scratch

Run with:
  uvicorn main:app --reload --port 8000

Interactive docs:
  http://localhost:8000/docs
"""

import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from schemas import (
    SensorReading, BatchSensorInput, StreamWindow,
    PredictionResponse, BatchPredictionResponse,
    BatchPredictionItem, ModelInfoResponse,
)
from model import load_or_train_model, predict_patient


# ─────────────────────────────────────────────────────────────────────────────
# Startup: load model into memory once when the server starts
# ─────────────────────────────────────────────────────────────────────────────
model_store = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("\n  MAX30102 Heart Risk API — starting up")
    model_store["model"], model_store["meta"] = load_or_train_model()
    print("  Ready.\n")
    yield
    print("  Shutting down.")


# ─────────────────────────────────────────────────────────────────────────────
# App
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title       = "MAX30102 Heart Risk API",
    description = (
        "AI-powered cardiac risk classification designed for the MAX30102 "
        "pulse oximeter sensor. Accepts BPM, SpO2, HRV, age, and sex. "
        "Returns NORMAL / WARNING / CRITICAL with recommended action."
    ),
    version     = "2.0.0",
    lifespan    = lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins  = ["*"],
    allow_methods  = ["*"],
    allow_headers  = ["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────────────────────────────────────
def get_model():
    if "model" not in model_store:
        raise HTTPException(status_code=503, detail="Model not loaded yet. Try again in a moment.")
    return model_store["model"]


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/", tags=["General"])
def root():
    return {
        "api"         : "MAX30102 Heart Risk API v2.0",
        "sensor"      : "MAX30102 pulse oximeter",
        "description" : "Send live sensor readings and get instant cardiac risk assessment.",
        "endpoints"   : {
            "POST /predict"        : "Single reading → NORMAL / WARNING / CRITICAL",
            "POST /predict/batch"  : "Multiple readings at once",
            "POST /predict/window" : "30-second averaged window (recommended for devices)",
            "GET  /model/info"     : "Model metadata and performance metrics",
            "GET  /model/retrain"  : "Retrain the model from scratch",
            "GET  /health"         : "Server and model status",
            "GET  /docs"           : "Swagger UI — test all endpoints interactively",
        }
    }


@app.get("/health", tags=["General"])
def health():
    model_loaded = "model" in model_store
    meta         = model_store.get("meta", {})
    return {
        "status"       : "healthy" if model_loaded else "degraded",
        "model_loaded" : model_loaded,
        "model_name"   : meta.get("model_name", "N/A"),
        "sensor"       : "MAX30102",
        "timestamp"    : time.time(),
    }


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
def predict_single(reading: SensorReading):
    """
    **Main endpoint — call this from your microcontroller.**

    Send current MAX30102 values and patient profile.
    Returns risk tier, recommended action, and alert flag.

    - `alert: true` → trigger ambulance call on your device.
    - `override_reason` → set if an emergency threshold fired directly
      (e.g. SpO2 dropped below 85%).
    """
    result = predict_patient(get_model(), reading.model_dump())
    return PredictionResponse(**result)


@app.post("/predict/batch", response_model=BatchPredictionResponse, tags=["Prediction"])
def predict_batch(payload: BatchSensorInput):
    """
    Send multiple readings at once.
    Useful for syncing a buffer of readings from the device.
    """
    model   = get_model()
    results = []

    for i, reading in enumerate(payload.readings):
        try:
            r = predict_patient(model, reading.model_dump())
            results.append(BatchPredictionItem(
                index=i, tier=r["tier"], score=r["score"],
                alert=r["alert"], action=r["action"],
                override_reason=r["override_reason"], error=None,
            ))
        except Exception as e:
            results.append(BatchPredictionItem(index=i, error=str(e)))

    return BatchPredictionResponse(
        total          = len(results),
        critical_count = sum(1 for r in results if r.tier == "CRITICAL"),
        warning_count  = sum(1 for r in results if r.tier == "WARNING"),
        normal_count   = sum(1 for r in results if r.tier == "NORMAL"),
        results        = results,
    )


@app.post("/predict/window", response_model=PredictionResponse, tags=["Prediction"])
def predict_window(window: StreamWindow):
    """
    **Recommended for production devices.**

    The device collects 30 seconds of readings, computes averages
    and minimums, then sends here. Uses worst-case (minimum) SpO2
    for the safest possible assessment.
    """
    safe_data = {
        "bpm"    : window.bpm_avg,
        "spo2"   : window.spo2_min,   # minimum SpO2 = worst case = safer
        "hrv_ms" : window.hrv_ms,
        "age"    : window.age,
        "sex"    : window.sex,
    }
    result = predict_patient(get_model(), safe_data)
    return PredictionResponse(**result)


@app.get("/model/info", response_model=ModelInfoResponse, tags=["Model"])
def model_info():
    """Returns metadata about the currently loaded model."""
    if "meta" not in model_store:
        raise HTTPException(status_code=503, detail="Model not loaded yet.")
    return ModelInfoResponse(**model_store["meta"])


@app.get("/model/retrain", tags=["Model"])
def retrain():
    """Retrains the model from the dataset. Takes 10-30 seconds."""
    try:
        model_store["model"], model_store["meta"] = load_or_train_model(force_retrain=True)
        return {
            "message": "Model retrained successfully.",
            "metrics": {
                "test_auc"      : model_store["meta"]["test_auc"],
                "test_accuracy" : model_store["meta"]["test_accuracy"],
                "cv_accuracy"   : model_store["meta"]["cv_accuracy"],
            },
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retraining failed: {str(e)}")
