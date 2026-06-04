"""
schemas.py — Pydantic request & response models for MAX30102 API
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict


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
