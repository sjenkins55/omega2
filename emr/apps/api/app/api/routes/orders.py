from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import date, datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.physician_order import PhysicianOrder, OrderType, OrderStatus
from app.models.patient import Patient

router = APIRouter(tags=["orders"])


class OrderCreate(BaseModel):
    order_type: OrderType
    description: str
    frequency: str | None = None
    duration_weeks: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    is_verbal_order: bool = False
    verbal_order_date: datetime | None = None
    visit_id: UUID | None = None
    notes: str | None = None


class OrderUpdate(BaseModel):
    status: OrderStatus | None = None
    description: str | None = None
    frequency: str | None = None
    end_date: date | None = None
    written_order_received: bool | None = None
    physician_name: str | None = None
    physician_npi: str | None = None
    notes: str | None = None


class OrderResponse(BaseModel):
    id: UUID
    patient_id: UUID
    visit_id: UUID | None = None
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
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/patients/{patient_id}/orders", response_model=list[OrderResponse])
async def list_orders(
    patient_id: UUID,
    status: OrderStatus | None = None,
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    query = select(PhysicianOrder).where(PhysicianOrder.patient_id == patient_id)
    if status:
        query = query.where(PhysicianOrder.status == status)
    query = query.order_by(PhysicianOrder.created_at.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/patients/{patient_id}/orders", response_model=OrderResponse, status_code=201)
async def create_order(patient_id: UUID, body: OrderCreate, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Patient).where(Patient.id == patient_id))
    if not r.scalar_one_or_none():
        raise HTTPException(404, "Patient not found")
    order = PhysicianOrder(patient_id=patient_id, **body.model_dump())
    db.add(order)
    await db.flush()
    await db.refresh(order)
    return order


@router.get("/orders/{order_id}", response_model=OrderResponse)
async def get_order(order_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PhysicianOrder).where(PhysicianOrder.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    return order


@router.patch("/orders/{order_id}", response_model=OrderResponse)
async def update_order(order_id: UUID, body: OrderUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PhysicianOrder).where(PhysicianOrder.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(order, field, value)
    await db.flush()
    await db.refresh(order)
    return order
