from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.core.auth import get_current_user, get_scoped_patient
from app.models.patient import Patient, PatientStatus
from app.models.visit import Visit

router = APIRouter(tags=["discharge"])


class DischargeRequest(BaseModel):
    discharge_date: date
    discharge_reason: str
    summary_narrative: str | None = None
    follow_up_provider: str | None = None
    follow_up_date: date | None = None
    patient_instructions: str | None = None


class DischargeSummaryResponse(BaseModel):
    patient_id: UUID
    mrn: str
    name: str
    discharge_date: date
    discharge_reason: str
    soc_date: date | None
    episode_days: int | None
    primary_dx: str | None
    summary_narrative: str | None
    visit_count: int
    final_risk_score: float | None


@router.post("/patients/{patient_id}/discharge", response_model=DischargeSummaryResponse)
async def discharge_patient(
    patient_id: UUID,
    body: DischargeRequest,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = await get_scoped_patient(patient_id, current_user, db)
    if patient.status == PatientStatus.discharged:
        raise HTTPException(400, "Patient is already discharged")

    patient.status = PatientStatus.discharged
    patient.discharge_date = body.discharge_date
    patient.discharge_reason = body.discharge_reason

    visits = (await db.execute(
        select(Visit).where(Visit.patient_id == patient_id)
    )).scalars().all()
    completed_visits = [v for v in visits if v.status == "completed"]

    episode_days = None
    if patient.soc_date:
        episode_days = (body.discharge_date - patient.soc_date).days

    summary_text = body.summary_narrative
    if not summary_text:
        summary_text = (
            f"{patient.first_name} {patient.last_name} was admitted to home health services "
            f"on {patient.soc_date} with a primary diagnosis of {patient.primary_dx or 'not specified'}. "
            f"The patient received {len(completed_visits)} skilled nursing visit(s) over a {episode_days or '?'}-day episode. "
            f"Discharged {body.discharge_date} — reason: {body.discharge_reason}."
        )

    await db.flush()

    return DischargeSummaryResponse(
        patient_id=patient_id,
        mrn=patient.mrn,
        name=f"{patient.first_name} {patient.last_name}",
        discharge_date=body.discharge_date,
        discharge_reason=body.discharge_reason,
        soc_date=patient.soc_date,
        episode_days=episode_days,
        primary_dx=patient.primary_dx,
        summary_narrative=summary_text,
        visit_count=len(completed_visits),
        final_risk_score=patient.ai_risk_score,
    )


@router.get("/patients/{patient_id}/discharge-summary", response_model=DischargeSummaryResponse)
async def get_discharge_summary(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = await get_scoped_patient(patient_id, current_user, db)
    if patient.status != PatientStatus.discharged:
        raise HTTPException(400, "Patient has not been discharged")

    visits = (await db.execute(
        select(Visit).where(Visit.patient_id == patient_id)
    )).scalars().all()
    completed_visits = [v for v in visits if v.status == "completed"]
    episode_days = None
    if patient.soc_date and patient.discharge_date:
        episode_days = (patient.discharge_date - patient.soc_date).days

    return DischargeSummaryResponse(
        patient_id=patient_id,
        mrn=patient.mrn,
        name=f"{patient.first_name} {patient.last_name}",
        discharge_date=patient.discharge_date,
        discharge_reason=patient.discharge_reason or "",
        soc_date=patient.soc_date,
        episode_days=episode_days,
        primary_dx=patient.primary_dx,
        summary_narrative=None,
        visit_count=len(completed_visits),
        final_risk_score=patient.ai_risk_score,
    )
