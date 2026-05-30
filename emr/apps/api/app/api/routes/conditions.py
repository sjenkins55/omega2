from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date
from app.db.base import get_db
from app.models.condition import Condition
from app.models.patient import Patient
from app.schemas.condition import ConditionCreate, ConditionConfirm, ConditionResponse

router = APIRouter(tags=["conditions"])


@router.get("/patients/{patient_id}/conditions", response_model=list[ConditionResponse])
async def list_conditions(
    patient_id: UUID,
    clinical_status: str | None = None,
    hcc_only: bool = False,
    unrecaptured: bool = False,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")

    query = select(Condition).where(Condition.patient_id == patient_id)
    if clinical_status:
        query = query.where(Condition.clinical_status == clinical_status)
    if hcc_only:
        query = query.where(Condition.hcc_code.isnot(None))
    if unrecaptured:
        current_year = date.today().year
        query = query.where(
            Condition.hcc_code.isnot(None),
            (Condition.recaptured_in_year.is_(None)) | (Condition.recaptured_in_year < current_year),
        )
    query = query.order_by(Condition.recorded_date.desc())
    rows = await db.execute(query)
    return rows.scalars().all()


@router.post("/patients/{patient_id}/conditions", response_model=ConditionResponse, status_code=201)
async def create_condition(
    patient_id: UUID,
    body: ConditionCreate,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")

    condition = Condition(patient_id=patient_id, **body.model_dump())
    db.add(condition)
    await db.flush()
    await db.refresh(condition)
    return condition


@router.get("/conditions/{condition_id}", response_model=ConditionResponse)
async def get_condition(condition_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    return condition


@router.patch("/conditions/{condition_id}", response_model=ConditionResponse)
async def update_condition(
    condition_id: UUID,
    body: ConditionConfirm,
    db: AsyncSession = Depends(get_db),
):
    """Provider confirms a provisional HCC condition for the current year."""
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(condition, field, value)
    await db.flush()
    await db.refresh(condition)
    return condition


@router.delete("/conditions/{condition_id}", status_code=204)
async def delete_condition(condition_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    await db.delete(condition)
