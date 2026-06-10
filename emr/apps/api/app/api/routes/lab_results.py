from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.lab_result import LabResult
from app.models.patient import Patient
from app.schemas.lab_result import LabResultCreate, LabResultResponse
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["lab_results"])


class LabResultUpdate(BaseModel):
    """Full update schema — all mutable lab result fields optional."""
    source: str | None = None
    loinc_code: str | None = None
    display_name: str | None = None
    category: str | None = None
    value_quantity: float | None = None
    value_string: str | None = None
    unit: str | None = None
    reference_range_low: float | None = None
    reference_range_high: float | None = None
    interpretation: str | None = None
    status: str | None = None
    collected_at: datetime | None = None
    resulted_at: datetime | None = None
    ordering_provider: str | None = None
    performing_lab: str | None = None
    visit_id: UUID | None = None
    external_id: str | None = None
    raw_fhir: dict | None = None


async def _check_lab_result_org(lab_result: LabResult, current_user, db: AsyncSession) -> None:
    """404 if the lab result's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == lab_result.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Lab result not found")


@router.get("/patients/{patient_id}/lab-results", response_model=list[LabResultResponse])
async def list_lab_results(
    patient_id: UUID,
    loinc_code: str | None = None,
    category: str | None = None,
    limit: int = Query(100, le=500),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)

    query = select(LabResult).where(LabResult.patient_id == patient_id)
    if loinc_code:
        query = query.where(LabResult.loinc_code == loinc_code)
    if category:
        query = query.where(LabResult.category == category)
    query = query.order_by(LabResult.collected_at.desc().nullslast()).limit(limit)
    rows = await db.execute(query)
    return rows.scalars().all()


@router.post("/patients/{patient_id}/lab-results", response_model=LabResultResponse, status_code=201)
async def create_lab_result(
    patient_id: UUID,
    body: LabResultCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)

    lab_result = LabResult(patient_id=patient_id, **body.model_dump())
    db.add(lab_result)
    await db.flush()
    await db.refresh(lab_result)
    return lab_result


@router.get("/lab-results/{lab_result_id}", response_model=LabResultResponse)
async def get_lab_result(
    lab_result_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(LabResult).where(LabResult.id == lab_result_id))
    lab_result = result.scalar_one_or_none()
    if not lab_result:
        raise HTTPException(404, "Lab result not found")
    await _check_lab_result_org(lab_result, current_user, db)
    return lab_result


@router.patch("/lab-results/{lab_result_id}", response_model=LabResultResponse)
async def update_lab_result(
    lab_result_id: UUID,
    body: LabResultUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(LabResult).where(LabResult.id == lab_result_id))
    lab_result = result.scalar_one_or_none()
    if not lab_result:
        raise HTTPException(404, "Lab result not found")
    await _check_lab_result_org(lab_result, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(lab_result, field, value)
    await db.flush()
    await db.refresh(lab_result)
    return lab_result
