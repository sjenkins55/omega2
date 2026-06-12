from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID
from app.db.base import get_db
from app.core.auth import get_current_user, get_scoped_patient, org_scope
from app.models.patient import Patient, PatientStatus
from app.models.user import UserRole
from app.schemas.patient import PatientCreate, PatientUpdate, PatientResponse, PatientListResponse

router = APIRouter(prefix="/patients", tags=["patients"])

_ADMIN_ONLY_UPDATE_FIELDS = {"mrn", "ai_risk_score", "ai_risk_factors", "ai_last_reviewed"}


@router.get("", response_model=PatientListResponse)
async def list_patients(
    status: PatientStatus | None = None,
    search: str | None = None,
    assigned_provider_id: UUID | None = None,
    high_risk: bool | None = None,
    limit: int = Query(50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    query = org_scope(select(Patient), Patient, current_user)
    if status:
        query = query.where(Patient.status == status)
    if search:
        term = f"%{search}%"
        query = query.where(
            Patient.first_name.ilike(term)
            | Patient.last_name.ilike(term)
            | Patient.mrn.ilike(term)
        )
    if assigned_provider_id:
        query = query.where(Patient.assigned_provider_id == assigned_provider_id)
    if high_risk is True:
        query = query.where(Patient.ai_risk_score >= 0.7)
    elif high_risk is False:
        query = query.where((Patient.ai_risk_score < 0.7) | (Patient.ai_risk_score.is_(None)))
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar()
    result = await db.execute(query.offset(offset).limit(limit).order_by(Patient.last_name))
    return PatientListResponse(patients=result.scalars().all(), total=total)


@router.get("/{patient_id}", response_model=PatientResponse)
async def get_patient(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return await get_scoped_patient(patient_id, current_user, db)


@router.post("", response_model=PatientResponse, status_code=201)
async def create_patient(
    body: PatientCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    data = body.model_dump()
    # Only super_admins may create patients in another org
    if data.get("organization_id") and current_user.role != UserRole.super_admin:
        if data["organization_id"] != current_user.organization_id:
            raise HTTPException(403, "Cannot create patients in another organization")
    if not data.get("organization_id"):
        data["organization_id"] = current_user.organization_id

    dup = await db.execute(
        select(Patient.id).where(
            Patient.mrn == data["mrn"],
            Patient.organization_id == data["organization_id"],
        )
    )
    if dup.scalar_one_or_none():
        raise HTTPException(409, "A patient with this MRN already exists in this organization")

    patient = Patient(**data)
    db.add(patient)
    await db.flush()
    await db.refresh(patient)
    return patient


@router.patch("/{patient_id}", response_model=PatientResponse)
async def update_patient(
    patient_id: UUID,
    body: PatientUpdate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = await get_scoped_patient(patient_id, current_user, db)
    updates = body.model_dump(exclude_unset=True)
    if _ADMIN_ONLY_UPDATE_FIELDS & updates.keys() and current_user.role not in (
        UserRole.admin,
        UserRole.super_admin,
    ):
        raise HTTPException(403, "Admin access required to modify MRN or AI risk fields")
    if "mrn" in updates and updates["mrn"] != patient.mrn:
        dup = await db.execute(
            select(Patient.id).where(
                Patient.mrn == updates["mrn"],
                Patient.organization_id == patient.organization_id,
                Patient.id != patient.id,
            )
        )
        if dup.scalar_one_or_none():
            raise HTTPException(409, "A patient with this MRN already exists in this organization")
    for field, value in updates.items():
        setattr(patient, field, value)
    await db.flush()
    await db.refresh(patient)
    return patient


@router.get("/{patient_id}/medication-safety")
async def medication_safety_check(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Drug–drug interaction (RxNav) and allergy cross-check for the patient's
    active medication list."""
    from app.services.drug_interactions import check_interactions, check_allergies

    patient = await get_scoped_patient(patient_id, current_user, db)
    meds = [
        m.get("name") for m in (patient.medications or [])
        if isinstance(m, dict) and m.get("name") and m.get("is_active", True)
    ]
    ddi = await check_interactions(meds)
    allergy_alerts = check_allergies(meds, patient.allergies or [])
    return {
        "patient_id": str(patient_id),
        "medications_checked": meds,
        "interactions": ddi["interactions"],
        "interaction_source": ddi["source"],
        "allergy_alerts": allergy_alerts,
        "has_critical_findings": bool(allergy_alerts)
        or any(str(i.get("severity", "")).lower() in ("high", "contraindicated") for i in ddi["interactions"]),
    }


@router.get("/{patient_id}/risk-brief")
async def get_risk_brief(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Trigger AI risk score computation for a patient using the agent loop."""
    from app.modules.ai_engine.visit_brief import compute_risk_score

    await get_scoped_patient(patient_id, current_user, db)
    return await compute_risk_score(str(patient_id), db)
