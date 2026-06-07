from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.oasis import OasisAssessment, OasisType, OasisStatus
from app.models.patient import Patient

router = APIRouter(tags=["oasis"])


class OasisCreate(BaseModel):
    assessment_type: OasisType
    assessment_date: date | None = None
    visit_id: UUID | None = None
    section_m0: dict | None = None
    section_m1: dict | None = None
    section_living: dict | None = None
    section_health: dict | None = None
    section_clinical: dict | None = None
    section_cognitive: dict | None = None
    section_functional: dict | None = None
    section_care_mgmt: dict | None = None
    section_gg: dict | None = None


class OasisUpdate(OasisCreate):
    status: OasisStatus | None = None


class OasisResponse(OasisCreate):
    id: UUID
    patient_id: UUID
    status: OasisStatus
    submitted_at: datetime | None = None
    iqies_submission_id: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/patients/{patient_id}/oasis", response_model=list[OasisResponse])
async def list_oasis(patient_id: UUID, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    result = await db.execute(
        select(OasisAssessment)
        .where(OasisAssessment.patient_id == patient_id)
        .order_by(OasisAssessment.assessment_date.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/oasis", response_model=OasisResponse, status_code=201)
async def create_oasis(patient_id: UUID, body: OasisCreate, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    assessment = OasisAssessment(patient_id=patient_id, **body.model_dump())
    db.add(assessment)
    await db.flush()
    await db.refresh(assessment)
    return assessment


@router.get("/oasis/{oasis_id}", response_model=OasisResponse)
async def get_oasis(oasis_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(OasisAssessment).where(OasisAssessment.id == oasis_id))
    a = result.scalar_one_or_none()
    if not a:
        raise HTTPException(404, "OASIS assessment not found")
    return a


@router.patch("/oasis/{oasis_id}", response_model=OasisResponse)
async def update_oasis(oasis_id: UUID, body: OasisUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(OasisAssessment).where(OasisAssessment.id == oasis_id))
    a = result.scalar_one_or_none()
    if not a:
        raise HTTPException(404, "OASIS assessment not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(a, field, value)
    if body.status == OasisStatus.submitted and not a.submitted_at:
        a.submitted_at = datetime.utcnow()
    await db.flush()
    await db.refresh(a)
    return a
