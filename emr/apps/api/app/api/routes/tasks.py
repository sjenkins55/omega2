from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime, timezone
from pydantic import BaseModel
from app.db.base import get_db
from app.models.task import Task, TaskStatus, TaskPriority, TaskCategory
from app.models.notification import Notification

router = APIRouter(prefix="/tasks", tags=["tasks"])


class TaskCreate(BaseModel):
    title: str
    description: str | None = None
    patient_id: UUID | None = None
    visit_id: UUID | None = None
    assigned_to_id: UUID | None = None
    priority: TaskPriority = TaskPriority.normal
    category: TaskCategory = TaskCategory.clinical
    due_at: datetime | None = None


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    assigned_to_id: UUID | None = None
    priority: TaskPriority | None = None
    status: TaskStatus | None = None
    due_at: datetime | None = None
    notes: str | None = None


class TaskResponse(BaseModel):
    id: UUID
    title: str
    description: str | None = None
    patient_id: UUID | None = None
    visit_id: UUID | None = None
    assigned_to_id: UUID | None = None
    created_by_id: UUID | None = None
    priority: TaskPriority
    status: TaskStatus
    category: TaskCategory
    due_at: datetime | None = None
    completed_at: datetime | None = None
    notes: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("", response_model=list[TaskResponse])
async def list_tasks(
    assigned_to_id: UUID | None = None,
    patient_id: UUID | None = None,
    status: TaskStatus | None = None,
    priority: TaskPriority | None = None,
    limit: int = Query(100, le=500),
    db: AsyncSession = Depends(get_db),
):
    query = select(Task)
    if assigned_to_id:
        query = query.where(Task.assigned_to_id == assigned_to_id)
    if patient_id:
        query = query.where(Task.patient_id == patient_id)
    if status:
        query = query.where(Task.status == status)
    if priority:
        query = query.where(Task.priority == priority)
    query = query.order_by(Task.due_at.asc().nullslast(), Task.created_at.desc()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.post("", response_model=TaskResponse, status_code=201)
async def create_task(body: TaskCreate, db: AsyncSession = Depends(get_db)):
    task = Task(**body.model_dump())
    db.add(task)
    await db.flush()

    # Notify assigned user
    if task.assigned_to_id:
        notif = Notification(
            user_id=task.assigned_to_id,
            patient_id=task.patient_id,
            type="task_assigned",
            title="New task assigned",
            message=task.title,
            action_url=f"/tasks/{task.id}",
        )
        db.add(notif)

    await db.refresh(task)
    return task


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Task not found")
    return task


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(task_id: UUID, body: TaskUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Task not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    if body.status == TaskStatus.completed and not task.completed_at:
        task.completed_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(task)
    return task


@router.delete("/{task_id}", status_code=204)
async def delete_task(task_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(404, "Task not found")
    await db.delete(task)
