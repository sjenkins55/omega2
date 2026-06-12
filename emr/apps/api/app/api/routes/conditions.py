from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date
from pydantic import BaseModel
from app.db.base import get_db
from app.models.condition import Condition
from app.models.patient import Patient
from app.schemas.condition import ConditionCreate, ConditionResponse
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["conditions"])


class ConditionUpdate(BaseModel):
    """Full update schema — all mutable condition fields optional.

    Supersedes ConditionConfirm (its fields are folded in), so the provider
    confirm workflow (verification_status / recaptured_in_year /
    recaptured_visit_id) keeps working through the same PATCH.
    """
    icd10_code: str | None = None
    icd10_description: str | None = None
    hcc_code: str | None = None
    hcc_description: str | None = None
    clinical_status: str | None = None
    verification_status: str | None = None
    is_primary: bool | None = None
    source: str | None = None
    onset_date: date | None = None
    abatement_date: date | None = None
    recorded_date: date | None = None
    asserter_name: str | None = None
    asserter_npi: str | None = None
    visit_id: UUID | None = None
    document_id: UUID | None = None
    recaptured_in_year: int | None = None
    recaptured_visit_id: UUID | None = None
    external_id: str | None = None
    raw_fhir: dict | None = None


async def _check_condition_org(condition: Condition, current_user, db: AsyncSession) -> None:
    """404 if the condition's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == condition.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Condition not found")


@router.get("/patients/{patient_id}/conditions", response_model=list[ConditionResponse])
async def list_conditions(
    patient_id: UUID,
    clinical_status: str | None = None,
    hcc_only: bool = False,
    unrecaptured: bool = False,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)

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
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)

    data = body.model_dump()
    # Auto-map ICD-10 → HCC V28 when no HCC code supplied
    if not data.get("hcc_code") and data.get("icd10_code"):
        from app.services.hcc_mapping import map_icd10_to_hcc

        hcc = map_icd10_to_hcc(data["icd10_code"])
        if hcc:
            data["hcc_code"] = hcc["hcc_code"]
            data["hcc_description"] = hcc["description"]

    condition = Condition(patient_id=patient_id, **data)
    db.add(condition)
    await db.flush()
    await db.refresh(condition)
    return condition


@router.get("/conditions/{condition_id}", response_model=ConditionResponse)
async def get_condition(
    condition_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    await _check_condition_org(condition, current_user, db)
    return condition


@router.patch("/conditions/{condition_id}", response_model=ConditionResponse)
async def update_condition(
    condition_id: UUID,
    body: ConditionUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update any mutable condition field (incl. provider confirm workflow)."""
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    await _check_condition_org(condition, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(condition, field, value)
    await db.flush()
    await db.refresh(condition)
    return condition


@router.delete("/conditions/{condition_id}", status_code=204)
async def delete_condition(
    condition_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Condition).where(Condition.id == condition_id))
    condition = result.scalar_one_or_none()
    if not condition:
        raise HTTPException(404, "Condition not found")
    await _check_condition_org(condition, current_user, db)
    await db.delete(condition)
