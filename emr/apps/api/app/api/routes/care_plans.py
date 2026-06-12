from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.care_plan import CarePlan
from app.models.patient import Patient
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["care_plans"])


async def _check_care_plan_org(plan: CarePlan, current_user, db: AsyncSession) -> None:
    """404 if the care plan's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == plan.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Care plan not found")


class GoalItem(BaseModel):
    text: str
    target_date: date | None = None
    status: str = "not_started"  # not_started | in_progress | achieved | discontinued
    progress_notes: str | None = None


class CarePlanCreate(BaseModel):
    created_by_id: UUID | None = None  # defaults to the current user
    status: str = "active"
    start_date: date | None = None
    review_date: date | None = None
    end_date: date | None = None
    long_term_goals: list[GoalItem] | None = None
    short_term_goals: list[GoalItem] | None = None
    functional_limitations: list[str] | None = None
    safety_measures: str | None = None
    nutritional_requirements: str | None = None
    activities_permitted: list[str] | None = None
    notes: str | None = None


class CarePlanUpdate(CarePlanCreate):
    pass


class CarePlanResponse(BaseModel):
    id: UUID
    patient_id: UUID
    created_by_id: UUID | None = None
    status: str
    start_date: date | None = None
    review_date: date | None = None
    end_date: date | None = None
    long_term_goals: list | None = None
    short_term_goals: list | None = None
    functional_limitations: list | None = None
    safety_measures: str | None = None
    nutritional_requirements: str | None = None
    activities_permitted: list | None = None
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/patients/{patient_id}/care-plans", response_model=list[CarePlanResponse])
async def list_care_plans(
    patient_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(
        select(CarePlan).where(CarePlan.patient_id == patient_id).order_by(CarePlan.created_at.desc())
    )
    return result.scalars().all()


@router.post("/patients/{patient_id}/care-plans", response_model=CarePlanResponse, status_code=201)
async def create_care_plan(
    patient_id: UUID,
    body: CarePlanCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    data = body.model_dump()
    if data.get("created_by_id") is None:
        data["created_by_id"] = current_user.id
    plan = CarePlan(patient_id=patient_id, **data)
    db.add(plan)
    await db.flush()
    await db.refresh(plan)
    return plan


@router.get("/care-plans/{plan_id}", response_model=CarePlanResponse)
async def get_care_plan(
    plan_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(CarePlan).where(CarePlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(404, "Care plan not found")
    await _check_care_plan_org(plan, current_user, db)
    return plan


@router.patch("/care-plans/{plan_id}", response_model=CarePlanResponse)
async def update_care_plan(
    plan_id: UUID,
    body: CarePlanUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(CarePlan).where(CarePlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(404, "Care plan not found")
    await _check_care_plan_org(plan, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    await db.flush()
    await db.refresh(plan)
    return plan
