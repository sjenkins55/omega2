from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime, timezone
from pydantic import BaseModel
from app.db.base import get_db
from app.models.oasis import OasisAssessment, OasisType, OasisStatus
from app.models.patient import Patient
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["oasis"])


class OasisCreate(BaseModel):
    assessment_type: OasisType
    assessment_date: date | None = None
    visit_id: UUID | None = None
    completed_by_id: UUID | None = None  # defaults to the current user
    submitted_at: datetime | None = None
    iqies_submission_id: str | None = None
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
    assessment_type: OasisType | None = None
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


async def _check_oasis_org(assessment: OasisAssessment, current_user, db: AsyncSession) -> None:
    """404 if the assessment's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == assessment.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "OASIS assessment not found")


@router.get("/patients/{patient_id}/oasis", response_model=list[OasisResponse])
async def list_oasis(
    patient_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(
        select(OasisAssessment)
        .where(OasisAssessment.patient_id == patient_id)
        .order_by(OasisAssessment.assessment_date.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/oasis", response_model=OasisResponse, status_code=201)
async def create_oasis(
    patient_id: UUID,
    body: OasisCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    data = body.model_dump()
    if data.get("completed_by_id") is None:
        data["completed_by_id"] = current_user.id
    assessment = OasisAssessment(patient_id=patient_id, **data)
    db.add(assessment)
    await db.flush()
    await db.refresh(assessment)
    return assessment


@router.get("/oasis/{oasis_id}", response_model=OasisResponse)
async def get_oasis(
    oasis_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(OasisAssessment).where(OasisAssessment.id == oasis_id))
    a = result.scalar_one_or_none()
    if not a:
        raise HTTPException(404, "OASIS assessment not found")
    await _check_oasis_org(a, current_user, db)
    return a


@router.patch("/oasis/{oasis_id}", response_model=OasisResponse)
async def update_oasis(
    oasis_id: UUID,
    body: OasisUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(OasisAssessment).where(OasisAssessment.id == oasis_id))
    a = result.scalar_one_or_none()
    if not a:
        raise HTTPException(404, "OASIS assessment not found")
    await _check_oasis_org(a, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(a, field, value)
    if body.status == OasisStatus.submitted and not a.submitted_at:
        a.submitted_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(a)
    return a
