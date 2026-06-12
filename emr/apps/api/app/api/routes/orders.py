from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.physician_order import PhysicianOrder, OrderType, OrderStatus
from app.models.patient import Patient
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(tags=["orders"])


class OrderCreate(BaseModel):
    order_type: OrderType
    status: OrderStatus = OrderStatus.pending
    description: str
    frequency: str | None = None
    duration_weeks: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    is_verbal_order: bool = False
    verbal_order_date: datetime | None = None
    written_order_received: bool = False
    countersigned_at: datetime | None = None
    visit_id: UUID | None = None
    plan_of_care_id: UUID | None = None
    document_id: UUID | None = None
    notes: str | None = None


class OrderUpdate(BaseModel):
    order_type: OrderType | None = None
    status: OrderStatus | None = None
    description: str | None = None
    frequency: str | None = None
    duration_weeks: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    written_order_received: bool | None = None
    is_verbal_order: bool | None = None
    verbal_order_date: datetime | None = None
    countersigned_at: datetime | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    visit_id: UUID | None = None
    plan_of_care_id: UUID | None = None
    document_id: UUID | None = None
    notes: str | None = None


class OrderResponse(BaseModel):
    id: UUID
    patient_id: UUID
    visit_id: UUID | None = None
    plan_of_care_id: UUID | None = None
    document_id: UUID | None = None
    order_type: OrderType
    status: OrderStatus
    description: str
    frequency: str | None = None
    duration_weeks: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    is_verbal_order: bool
    verbal_order_date: datetime | None = None
    written_order_received: bool
    countersigned_at: datetime | None = None
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


async def _check_order_org(order: PhysicianOrder, current_user, db: AsyncSession) -> None:
    """404 if the order's patient belongs to another organization."""
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == order.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Order not found")


@router.get("/patients/{patient_id}/orders", response_model=list[OrderResponse])
async def list_orders(
    patient_id: UUID,
    status: OrderStatus | None = None,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    query = select(PhysicianOrder).where(PhysicianOrder.patient_id == patient_id)
    if status:
        query = query.where(PhysicianOrder.status == status)
    query = query.order_by(PhysicianOrder.created_at.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/patients/{patient_id}/orders", response_model=OrderResponse, status_code=201)
async def create_order(
    patient_id: UUID,
    body: OrderCreate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await get_scoped_patient(patient_id, current_user, db)
    order = PhysicianOrder(patient_id=patient_id, **body.model_dump())
    db.add(order)
    await db.flush()
    await db.refresh(order)
    return order


@router.get("/orders/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(PhysicianOrder).where(PhysicianOrder.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    await _check_order_org(order, current_user, db)
    return order


@router.patch("/orders/{order_id}", response_model=OrderResponse)
async def update_order(
    order_id: UUID,
    body: OrderUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(PhysicianOrder).where(PhysicianOrder.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    await _check_order_org(order, current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(order, field, value)
    await db.flush()
    await db.refresh(order)
    return order
