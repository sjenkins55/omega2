from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.notification import Notification
from app.core.auth import get_current_user
from app.models.user import User

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationResponse(BaseModel):
    id: UUID
    user_id: UUID
    patient_id: UUID | None = None
    type: str
    title: str
    message: str
    action_url: str | None = None
    read: bool
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("", response_model=list[NotificationResponse])
async def list_notifications(
    unread_only: bool = False,
    limit: int = Query(50, le=200),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Notification).where(Notification.user_id == current_user.id)
    if unread_only:
        query = query.where(Notification.read == False)  # noqa: E712
    query = query.order_by(Notification.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/unread-count")
async def unread_count(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.user_id == current_user.id,
            Notification.read == False,  # noqa: E712
        )
    )
    return {"count": len(result.scalars().all())}


@router.patch("/{notification_id}/read")
async def mark_read(
    notification_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(Notification.id == notification_id, Notification.user_id == current_user.id)
        .values(read=True)
    )
    return {"ok": True}


@router.post("/mark-all-read")
async def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.read == False)  # noqa: E712
        .values(read=True)
    )
    return {"ok": True}
