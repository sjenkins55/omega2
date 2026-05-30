from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from app.db.base import get_db
from app.models.lab_result import LabResult
from app.models.patient import Patient
from app.schemas.lab_result import LabResultCreate, LabResultResponse

router = APIRouter(tags=["lab_results"])


@router.get("/patients/{patient_id}/lab-results", response_model=list[LabResultResponse])
async def list_lab_results(
    patient_id: UUID,
    loinc_code: str | None = None,
    category: str | None = None,
    limit: int = Query(100, le=500),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")

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
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")

    lab_result = LabResult(patient_id=patient_id, **body.model_dump())
    db.add(lab_result)
    await db.flush()
    await db.refresh(lab_result)
    return lab_result


@router.get("/lab-results/{lab_result_id}", response_model=LabResultResponse)
async def get_lab_result(lab_result_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LabResult).where(LabResult.id == lab_result_id))
    lab_result = result.scalar_one_or_none()
    if not lab_result:
        raise HTTPException(404, "Lab result not found")
    return lab_result
