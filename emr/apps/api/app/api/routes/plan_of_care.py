from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.plan_of_care import PlanOfCare
from app.models.patient import Patient
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["plan_of_care"])


class PlanOfCareCreate(BaseModel):
    created_by_id: UUID | None = None  # defaults to the current user
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
    signature_status: str | None = None
    signed_at: datetime | None = None
    signature_document_id: UUID | None = None


class PlanOfCareUpdate(PlanOfCareCreate):
    status: str | None = None


class PlanOfCareResponse(BaseModel):
    id: UUID
    patient_id: UUID
    created_by_id: UUID | None = None
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
    signature_status: str
    signed_at: datetime | None = None
    signature_document_id: UUID | None = None
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


async def _check_poc_org(poc: PlanOfCare, current_user, db: AsyncSession) -> None:
    """404 if the plan of care's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == poc.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Plan of care not found")


@router.get("/patients/{patient_id}/plans-of-care", response_model=list[PlanOfCareResponse])
async def list_plans_of_care(
    patient_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(
        select(PlanOfCare).where(PlanOfCare.patient_id == patient_id).order_by(PlanOfCare.created_at.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/plans-of-care", response_model=PlanOfCareResponse, status_code=201)
async def create_plan_of_care(
    patient_id: UUID,
    body: PlanOfCareCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    data = body.model_dump(exclude_unset=True)
    if data.get("created_by_id") is None:
        data["created_by_id"] = current_user.id
    poc = PlanOfCare(patient_id=patient_id, **data)
    db.add(poc)
    await db.flush()
    await db.refresh(poc)
    return poc


@router.get("/plans-of-care/{poc_id}", response_model=PlanOfCareResponse)
async def get_plan_of_care(
    poc_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(PlanOfCare).where(PlanOfCare.id == poc_id))
    poc = result.scalar_one_or_none()
    if not poc:
        raise HTTPException(404, "Plan of care not found")
    await _check_poc_org(poc, current_user, db)
    return poc


@router.patch("/plans-of-care/{poc_id}", response_model=PlanOfCareResponse)
async def update_plan_of_care(
    poc_id: UUID,
    body: PlanOfCareUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(PlanOfCare).where(PlanOfCare.id == poc_id))
    poc = result.scalar_one_or_none()
    if not poc:
        raise HTTPException(404, "Plan of care not found")
    await _check_poc_org(poc, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(poc, field, value)
    await db.flush()
    await db.refresh(poc)
    return poc
