from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID
from app.db.base import get_db
from app.models.patient import Patient, PatientStatus
from app.schemas.patient import PatientCreate, PatientUpdate, PatientResponse, PatientListResponse

router = APIRouter(prefix="/patients", tags=["patients"])


@router.get("", response_model=PatientListResponse)
async def list_patients(
    status: PatientStatus | None = None,
    search: str | None = None,
    assigned_provider_id: UUID | None = None,
    high_risk: bool | None = None,
    limit: int = Query(50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    query = select(Patient)
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
async def get_patient(patient_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, "Patient not found")
    return patient


@router.post("", response_model=PatientResponse, status_code=201)
async def create_patient(body: PatientCreate, db: AsyncSession = Depends(get_db)):
    patient = Patient(**body.model_dump())
    db.add(patient)
    await db.flush()
    await db.refresh(patient)
    return patient


@router.patch("/{patient_id}", response_model=PatientResponse)
async def update_patient(patient_id: UUID, body: PatientUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, "Patient not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(patient, field, value)
    await db.flush()
    await db.refresh(patient)
    return patient


@router.get("/{patient_id}/risk-brief")
async def get_risk_brief(patient_id: UUID, db: AsyncSession = Depends(get_db)):
    """Trigger AI risk score computation for a patient using the agent loop."""
    from app.modules.ai_engine.visit_brief import compute_risk_score

    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not result.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")

    return await compute_risk_score(str(patient_id), db)
