from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.eligibility import EligibilityCheck
from app.models.patient import Patient
from app.core.auth import get_current_user, get_scoped_patient

router = APIRouter(tags=["eligibility"])


class EligibilityRequest(BaseModel):
    payer_name: str | None = None
    payer_id: str | None = None
    insurance_id: str | None = None
    insurance_type: str | None = None


class EligibilityResponse(BaseModel):
    id: UUID
    patient_id: UUID
    payer_name: str | None = None
    payer_id: str | None = None
    insurance_id: str | None = None
    insurance_type: str | None = None
    coverage_active: bool | None = None
    coverage_dates: dict | None = None
    benefits: dict | None = None
    notes: str | None = None
    checked_at: datetime

    class Config:
        from_attributes = True


@router.get("/patients/{patient_id}/eligibility", response_model=list[EligibilityResponse])
async def list_eligibility_checks(
    patient_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(
        select(EligibilityCheck)
        .where(EligibilityCheck.patient_id == patient_id)
        .order_by(EligibilityCheck.checked_at.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/eligibility", response_model=EligibilityResponse, status_code=201)
async def check_eligibility(
    patient_id: UUID,
    body: EligibilityRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    patient = await get_scoped_patient(patient_id, current_user, db)

    # Production: call 270/271 EDI clearinghouse (Change Healthcare, Availity, etc.)
    # Stub response simulates a successful Medicare eligibility check.
    payer_name = body.payer_name or (patient.insurance_type.value.title() if patient.insurance_type else "Unknown")
    stub_result = {
        "coverage_active": True,
        "coverage_dates": {"start": "2026-01-01", "end": "2026-12-31"},
        "benefits": {
            "home_health_covered": True,
            "visits_remaining": None,  # unlimited under Medicare Part A
            "copay": 0,
            "deductible_met": True,
            "deductible_total": 0,
        },
        "notes": "Stub response — wire in clearinghouse credentials to get live 271.",
    }

    check = EligibilityCheck(
        patient_id=patient_id,
        payer_name=payer_name,
        payer_id=body.payer_id or patient.insurance_id,
        insurance_id=body.insurance_id or patient.insurance_id,
        insurance_type=body.insurance_type or (patient.insurance_type.value if patient.insurance_type else None),
        **stub_result,
        raw_response=stub_result,
    )
    db.add(check)
    await db.flush()
    await db.refresh(check)
    return check
