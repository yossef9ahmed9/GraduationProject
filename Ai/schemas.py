"""
schemas.py — Pydantic request & response models for MAX30102 API
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Literal


# ─────────────────────────────────────────────────────────────────────────────
# REQUEST SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────

class SensorReading(BaseModel):
    """Single reading from the MAX30102 sensor + patient profile."""
    bpm    : float = Field(..., ge=20,  le=300,  description="Heart rate in BPM")
    spo2   : float = Field(..., ge=50,  le=100,  description="Blood oxygen saturation %")
    hrv_ms : float = Field(..., ge=1,   le=200,  description="Heart rate variability in ms")
    age    : int   = Field(..., ge=1,   le=120,  description="Patient age in years")
    sex    : int   = Field(1,   ge=0,   le=1,    description="0 = female, 1 = male")

    model_config = {
        "json_schema_extra": {
            "example": {
                "bpm": 74.0, "spo2": 97.4,
                "hrv_ms": 52.0, "age": 45, "sex": 1
            }
        }
    }


class BatchSensorInput(BaseModel):
    """Multiple sensor readings for batch prediction."""
    readings: List[SensorReading] = Field(..., min_length=1, max_length=200)


class StreamWindow(BaseModel):
    """30-second averaged window — recommended for production devices."""
    bpm_avg  : float = Field(..., description="Average BPM over the window")
    bpm_min  : float = Field(..., description="Minimum BPM in the window")
    bpm_max  : float = Field(..., description="Maximum BPM in the window")
    spo2_avg : float = Field(..., description="Average SpO2 over the window")
    spo2_min : float = Field(..., description="Minimum SpO2 in the window")
    hrv_ms   : float = Field(..., description="HRV calculated from the full window")
    age      : int   = Field(..., ge=1, le=120)
    sex      : int   = Field(1,   ge=0, le=1)

    model_config = {
        "json_schema_extra": {
            "example": {
                "bpm_avg": 78.2, "bpm_min": 71.0, "bpm_max": 88.0,
                "spo2_avg": 97.1, "spo2_min": 96.5,
                "hrv_ms": 48.5, "age": 52, "sex": 1
            }
        }
    }


class TrendReading(BaseModel):
    """A single historical reading for trend analysis."""
    bpm    : float = Field(..., description="Heart rate in BPM")
    spo2   : float = Field(..., description="Blood oxygen saturation %")
    timestamp_offset_sec: float = Field(..., description="Seconds ago this reading was taken (0 = latest)")

class TrendRequest(BaseModel):
    """Last N readings for a patient, used to forecast near-future risk."""
    readings : List[TrendReading] = Field(..., min_length=3, max_length=60,
                                          description="At least 3 readings, ordered newest-first")
    age      : int   = Field(..., ge=1, le=120)
    sex      : int   = Field(1,  ge=0, le=1)
    hrv_ms   : float = Field(50.0, ge=1, le=200, description="Latest HRV reading")

    model_config = {
        "json_schema_extra": {
            "example": {
                "readings": [
                    {"bpm": 95.0, "spo2": 94.5, "timestamp_offset_sec": 0},
                    {"bpm": 90.0, "spo2": 95.2, "timestamp_offset_sec": 20},
                    {"bpm": 84.0, "spo2": 96.1, "timestamp_offset_sec": 40},
                    {"bpm": 78.0, "spo2": 97.0, "timestamp_offset_sec": 60},
                ],
                "age": 55, "sex": 1, "hrv_ms": 42.0
            }
        }
    }


class TrendForecastResponse(BaseModel):
    current_tier          : str             = Field(..., description="Risk tier for the latest reading")
    trend_direction       : str             = Field(..., description="IMPROVING / STABLE / WORSENING")
    bpm_slope             : float           = Field(..., description="BPM change per minute (positive = rising)")
    spo2_slope            : float           = Field(..., description="SpO2 change per minute (positive = rising)")
    forecast_tier_5min    : str             = Field(..., description="Predicted risk tier in ~5 minutes")
    forecast_tier_10min   : str             = Field(..., description="Predicted risk tier in ~10 minutes")
    alert                 : bool            = Field(..., description="True if forecasted deterioration is dangerous")
    message               : str             = Field(..., description="Human-readable forecast summary")
    confidence            : float           = Field(..., description="Confidence in trend estimate 0-100")
    time_to_danger_min    : Optional[float] = Field(None, description="Minutes until a danger threshold is crossed")
    window_stats          : Optional[Dict[str, float]] = Field(None, description="Window statistics: mean/max/min/std for BPM and SpO2")


# ─────────────────────────────────────────────────────────────────────────────
# RESPONSE SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────

class PredictionResponse(BaseModel):
    tier            : str            = Field(..., description="NORMAL / WARNING / CRITICAL")
    score           : float          = Field(..., description="Critical probability 0-100")
    confidence      : float          = Field(..., description="Model confidence 0-100")
    action          : str            = Field(..., description="Recommended action")
    message         : str            = Field(..., description="Detailed patient advice")
    alert           : bool           = Field(..., description="True = trigger ambulance alert")
    override_reason : Optional[str]  = Field(None, description="Set if an emergency override fired")
    probabilities   : Dict[str, float] = Field(..., description="Probability % for each tier")


class BatchPredictionItem(BaseModel):
    index           : int
    tier            : Optional[str]   = None
    score           : Optional[float] = None
    alert           : Optional[bool]  = None
    action          : Optional[str]   = None
    override_reason : Optional[str]   = None
    error           : Optional[str]   = None


class BatchPredictionResponse(BaseModel):
    total          : int
    critical_count : int
    warning_count  : int
    normal_count   : int
    results        : List[BatchPredictionItem]


class ModelInfoResponse(BaseModel):
    model_name    : str
    sensor        : str
    test_auc      : float
    test_accuracy : float
    cv_accuracy   : float
    n_features    : int
    features      : List[str]
    trained_on    : int
    classes       : List[str]
    model_path    : str
