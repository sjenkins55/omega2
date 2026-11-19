import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, JSON, ForeignKey, Enum as SAEnum, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class WorkflowStatus(str, enum.Enum):
    draft = "draft"
    active = "active"
    paused = "paused"
    archived = "archived"


class WorkflowRunStatus(str, enum.Enum):
    pending = "pending"
    running = "running"
    completed = "completed"
    failed = "failed"
    skipped = "skipped"


class TriggerType(str, enum.Enum):
    visit_completed = "visit_completed"
    document_received = "document_received"
    lab_result_received = "lab_result_received"
    patient_admitted = "patient_admitted"
    patient_discharged = "patient_discharged"
    risk_score_changed = "risk_score_changed"
    scheduled = "scheduled"
    manual = "manual"
    ai_flag = "ai_flag"


class Workflow(Base):
    """Power-Automate-style workflow definition."""
    __tablename__ = "workflows"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[WorkflowStatus] = mapped_column(SAEnum(WorkflowStatus), default=WorkflowStatus.draft)

    trigger_type: Mapped[TriggerType] = mapped_column(SAEnum(TriggerType))
    trigger_config: Mapped[dict] = mapped_column(JSON, default=dict)

    # DAG of steps: [{id, type, config, next_steps, conditions}]
    steps: Mapped[list] = mapped_column(JSON, default=list)

    # Optional filter conditions on the trigger
    conditions: Mapped[list] = mapped_column(JSON, default=list)

    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)

    run_count: Mapped[int] = mapped_column(default=0)
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    runs: Mapped[list["WorkflowRun"]] = relationship("WorkflowRun", back_populates="workflow")


class WorkflowRun(Base):
    __tablename__ = "workflow_runs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    workflow_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("workflows.id"), index=True)
    status: Mapped[WorkflowRunStatus] = mapped_column(SAEnum(WorkflowRunStatus), default=WorkflowRunStatus.pending)

    trigger_payload: Mapped[dict | None] = mapped_column(JSON)
    context: Mapped[dict | None] = mapped_column(JSON)
    step_results: Mapped[list] = mapped_column(JSON, default=list)
    error: Mapped[str | None] = mapped_column(Text)

    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    workflow: Mapped["Workflow"] = relationship("Workflow", back_populates="runs")
