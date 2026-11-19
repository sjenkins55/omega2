from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.adt_event import ADTEvent
from app.models.patient import Patient

router = APIRouter(prefix="/adt", tags=["adt"])


class ADTInbound(BaseModel):
    mrn: str | None = None
    patient_name: str | None = None
    event_type: str  # "admit" | "discharge" | "transfer"
    event_datetime: datetime | None = None
    hospital_name: str | None = None
    hospital_npi: str | None = None
    discharge_disposition: str | None = None
    admitting_diagnosis: str | None = None
    raw_payload: dict | None = None


class ADTEventResponse(BaseModel):
    id: UUID
    patient_id: UUID | None = None
    mrn_in_message: str | None = None
    event_type: str
    event_datetime: datetime | None = None
    hospital_name: str | None = None
    discharge_disposition: str | None = None
    matched: bool
    workflow_triggered: bool
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/inbound", response_model=ADTEventResponse, status_code=201)
async def receive_adt(body: ADTInbound, db: AsyncSession = Depends(get_db)):
    """
    Receive ADT (Admit/Discharge/Transfer) notification from a hospital.
    Automatically matches to a patient by MRN and triggers workflows.
    """
    from app.modules.workflows.engine import workflow_engine

    # Try to match patient by MRN
    patient_id = None
    matched = False
    if body.mrn:
        r = await db.execute(select(Patient).where(Patient.mrn == body.mrn))
        patient = r.scalar_one_or_none()
        if patient:
            patient_id = patient.id
            matched = True

    event = ADTEvent(
        patient_id=patient_id,
        mrn_in_message=body.mrn,
        patient_name_in_message=body.patient_name,
        event_type=body.event_type,
        event_datetime=body.event_datetime,
        hospital_name=body.hospital_name,
        hospital_npi=body.hospital_npi,
        discharge_disposition=body.discharge_disposition,
        admitting_diagnosis=body.admitting_diagnosis,
        matched=matched,
        raw_payload=body.raw_payload,
    )
    db.add(event)

    workflow_triggered = False
    if matched and patient_id:
        trigger_type = {
            "admit": "patient_admitted",
            "discharge": "patient_discharged",
            "transfer": "patient_admitted",
        }.get(body.event_type)

        if trigger_type:
            await workflow_engine.trigger(trigger_type, {
                "patient_id": str(patient_id),
                "hospital_name": body.hospital_name,
                "adt_event_type": body.event_type,
                "discharge_disposition": body.discharge_disposition,
            }, db)
            workflow_triggered = True
            event.workflow_triggered = True

    await db.flush()
    await db.refresh(event)
    return event


@router.get("", response_model=list[ADTEventResponse])
async def list_adt_events(
    patient_id: UUID | None = None,
    event_type: str | None = None,
    matched: bool | None = None,
    limit: int = Query(100, le=500),
    db: AsyncSession = Depends(get_db),
):
    query = select(ADTEvent)
    if patient_id:
        query = query.where(ADTEvent.patient_id == patient_id)
    if event_type:
        query = query.where(ADTEvent.event_type == event_type)
    if matched is not None:
        query = query.where(ADTEvent.matched == matched)
    query = query.order_by(ADTEvent.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
