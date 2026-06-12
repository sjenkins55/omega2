from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from app.models.workflow import WorkflowStatus, TriggerType


class WorkflowCreate(BaseModel):
    name: str
    description: str | None = None
    trigger_type: TriggerType
    trigger_config: dict = {}
    steps: list = []
    conditions: list = []


class WorkflowUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    status: WorkflowStatus | None = None
    trigger_config: dict | None = None
    steps: list | None = None
    conditions: list | None = None


class WorkflowResponse(BaseModel):
    id: UUID
    name: str
    description: str | None
    status: WorkflowStatus
    trigger_type: TriggerType
    trigger_config: dict
    steps: list
    conditions: list
    run_count: int
    last_run_at: datetime | None
    created_at: datetime

    class Config:
        from_attributes = True
