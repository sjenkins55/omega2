from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.plan_of_care import PlanOfCare
from app.models.patient import Patient

router = APIRouter(tags=["plan_of_care"])


class PlanOfCareCreate(BaseModel):
    cert_from: date | None = None
    cert_through: date | None = None
    primary_diagnosis_code: str | None = None
    primary_diagnosis_desc: str | None = None
    secondary_diagnoses: list | None = None
    skilled_nursing_orders: str | None = None
    therapy_orders: str | None = None
    medications: list | None = None
    goals: str | None = None
    functional_limitations: list | None = None
    activities_permitted: list | None = None
    safety_measures: str | None = None
    nutritional_requirements: str | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    physician_address: str | None = None
    physician_phone: str | None = None


class PlanOfCareUpdate(PlanOfCareCreate):
    signature_status: str | None = None
    signed_at: datetime | None = None
    status: str | None = None


class PlanOfCareResponse(PlanOfCareCreate):
    id: UUID
    patient_id: UUID
    signature_status: str
    signed_at: datetime | None = None
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/patients/{patient_id}/plans-of-care", response_model=list[PlanOfCareResponse])
async def list_plans_of_care(patient_id: UUID, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    result = await db.execute(
        select(PlanOfCare).where(PlanOfCare.patient_id == patient_id).order_by(PlanOfCare.created_at.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/plans-of-care", response_model=PlanOfCareResponse, status_code=201)
async def create_plan_of_care(patient_id: UUID, body: PlanOfCareCreate, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    poc = PlanOfCare(patient_id=patient_id, **body.model_dump())
    db.add(poc)
    await db.flush()
    await db.refresh(poc)
    return poc


@router.get("/plans-of-care/{poc_id}", response_model=PlanOfCareResponse)
async def get_plan_of_care(poc_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PlanOfCare).where(PlanOfCare.id == poc_id))
    poc = result.scalar_one_or_none()
    if not poc:
        raise HTTPException(404, "Plan of care not found")
    return poc


@router.patch("/plans-of-care/{poc_id}", response_model=PlanOfCareResponse)
async def update_plan_of_care(poc_id: UUID, body: PlanOfCareUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PlanOfCare).where(PlanOfCare.id == poc_id))
    poc = result.scalar_one_or_none()
    if not poc:
        raise HTTPException(404, "Plan of care not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(poc, field, value)
    await db.flush()
    await db.refresh(poc)
    return poc
