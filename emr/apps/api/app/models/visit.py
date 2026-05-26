import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, JSON, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class VisitStatus(str, enum.Enum):
    scheduled = "scheduled"
    in_progress = "in_progress"
    completed = "completed"
    cancelled = "cancelled"
    missed = "missed"


class VisitType(str, enum.Enum):
    skilled_nursing = "skilled_nursing"
    physical_therapy = "physical_therapy"
    occupational_therapy = "occupational_therapy"
    speech_therapy = "speech_therapy"
    social_work = "social_work"
    aide = "aide"
    telehealth = "telehealth"


class Visit(Base):
    __tablename__ = "visits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    clinician_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    visit_type: Mapped[VisitType] = mapped_column(SAEnum(VisitType))
    status: Mapped[VisitStatus] = mapped_column(SAEnum(VisitStatus), default=VisitStatus.scheduled)

    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Raw clinician input (voice or text)
    raw_note: Mapped[str | None] = mapped_column(Text)
    audio_url: Mapped[str | None] = mapped_column(String(500))

    # AI-processed structured note
    structured_note: Mapped[dict | None] = mapped_column(JSON)
    subjective: Mapped[str | None] = mapped_column(Text)
    objective: Mapped[str | None] = mapped_column(Text)
    assessment: Mapped[str | None] = mapped_column(Text)
    plan: Mapped[str | None] = mapped_column(Text)

    # AI recommendations shown before visit
    pre_visit_brief: Mapped[dict | None] = mapped_column(JSON)

    # Auto-generated actions
    action_items: Mapped[list | None] = mapped_column(JSON, default=list)
    triggered_workflows: Mapped[list | None] = mapped_column(JSON, default=list)

    vital_signs: Mapped[dict | None] = mapped_column(JSON)
    clinical_findings: Mapped[dict | None] = mapped_column(JSON)

    note_finalized: Mapped[bool] = mapped_column(default=False)
    ai_processing_status: Mapped[str] = mapped_column(String(50), default="pending")

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="visits")
    clinician: Mapped["User"] = relationship("User", back_populates="visits")
