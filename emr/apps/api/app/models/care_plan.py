import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Text, JSON, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class CarePlan(Base):
    __tablename__ = "care_plans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # "active" | "draft" | "superseded" | "completed"
    status: Mapped[str] = mapped_column(String(20), default="active")
    start_date: Mapped[date | None] = mapped_column(Date)
    review_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)

    # Each goal: {text, target_date, status: "not_started"|"in_progress"|"achieved"|"discontinued", progress_notes}
    long_term_goals: Mapped[list | None] = mapped_column(JSON, default=list)
    short_term_goals: Mapped[list | None] = mapped_column(JSON, default=list)

    # Functional/safety/nutritional
    functional_limitations: Mapped[list | None] = mapped_column(JSON, default=list)
    safety_measures: Mapped[str | None] = mapped_column(Text)
    nutritional_requirements: Mapped[str | None] = mapped_column(Text)
    activities_permitted: Mapped[list | None] = mapped_column(JSON, default=list)

    notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient")
