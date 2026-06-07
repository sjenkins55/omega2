from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from pydantic import BaseModel
from app.db.base import get_db
from app.models.visit import Visit, VisitStatus
from app.models.patient import Patient

router = APIRouter(tags=["vitals"])


class VitalThreshold(BaseModel):
    weight_gain_alert_lbs: float = 2.0
    bp_systolic_high: int = 160
    bp_systolic_low: int = 90
    o2_sat_low: float = 92.0
    pulse_high: int = 110
    pulse_low: int = 50


@router.get("/patients/{patient_id}/vitals-trend")
async def vitals_trend(
    patient_id: UUID,
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Return time-series vitals extracted from completed visits, with breach alerts."""
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    patient = r.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, "Patient not found")

    visits = (await db.execute(
        select(Visit)
        .where(Visit.patient_id == patient_id, Visit.vital_signs.isnot(None))
        .order_by(Visit.scheduled_at.desc())
        .limit(limit)
    )).scalars().all()

    trend = []
    for v in visits:
        vs = v.vital_signs or {}
        trend.append({
            "visit_id": str(v.id),
            "date": v.scheduled_at.isoformat() if v.scheduled_at else None,
            "weight_lbs": vs.get("weight_lbs"),
            "bp": vs.get("bp"),
            "hr": vs.get("hr"),
            "o2_sat": vs.get("o2_sat"),
            "temp_f": vs.get("temp_f"),
            "rr": vs.get("rr"),
        })

    # Alert detection
    alerts = []
    weights = [t["weight_lbs"] for t in trend if t["weight_lbs"] is not None]
    if len(weights) >= 2 and weights[0] - weights[1] >= 2.0:
        alerts.append({
            "type": "weight_gain",
            "message": f"Weight up {weights[0] - weights[1]:.1f} lbs since last visit",
            "severity": "high" if weights[0] - weights[1] >= 5 else "moderate",
        })
    if trend:
        latest = trend[0]
        if latest.get("o2_sat") and latest["o2_sat"] < 92:
            alerts.append({"type": "low_o2", "message": f"O2 sat {latest['o2_sat']}% below threshold", "severity": "critical"})
        if latest.get("hr") and latest["hr"] > 110:
            alerts.append({"type": "tachycardia", "message": f"HR {latest['hr']} bpm elevated", "severity": "high"})

    return {
        "patient_id": str(patient_id),
        "baseline_weight_lbs": patient.baseline_weight_lbs,
        "data_points": trend,
        "alerts": alerts,
    }
