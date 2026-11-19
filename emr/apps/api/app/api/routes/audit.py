from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.audit_event import AuditEvent

router = APIRouter(prefix="/admin/audit", tags=["audit"])


class AuditEventResponse(BaseModel):
    id: UUID
    user_id: UUID | None = None
    user_email: str | None = None
    action: str
    resource_type: str
    resource_id: str | None = None
    ip_address: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("", response_model=list[AuditEventResponse])
async def list_audit_events(
    user_id: UUID | None = None,
    resource_type: str | None = None,
    resource_id: str | None = None,
    action: str | None = None,
    limit: int = Query(100, le=1000),
    db: AsyncSession = Depends(get_db),
):
    query = select(AuditEvent)
    if user_id:
        query = query.where(AuditEvent.user_id == user_id)
    if resource_type:
        query = query.where(AuditEvent.resource_type == resource_type)
    if resource_id:
        query = query.where(AuditEvent.resource_id == resource_id)
    if action:
        query = query.where(AuditEvent.action == action)
    query = query.order_by(AuditEvent.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
