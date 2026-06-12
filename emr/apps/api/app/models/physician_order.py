import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Text, ForeignKey, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class OrderType(str, enum.Enum):
    skilled_nursing = "skilled_nursing"
    physical_therapy = "physical_therapy"
    occupational_therapy = "occupational_therapy"
    speech_therapy = "speech_therapy"
    aide = "aide"
    lab = "lab"
    medication = "medication"
    wound_care = "wound_care"
    other = "other"


class OrderStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    completed = "completed"
    cancelled = "cancelled"
    expired = "expired"


class PhysicianOrder(Base):
    __tablename__ = "physician_orders"
    __table_args__ = (
        Index("ix_orders_patient_status", "patient_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    visit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), nullable=True)
    document_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("documents.id"), nullable=True)
    plan_of_care_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    order_type: Mapped[OrderType] = mapped_column()
    status: Mapped[OrderStatus] = mapped_column(default=OrderStatus.pending)

    description: Mapped[str] = mapped_column(Text)
    frequency: Mapped[str | None] = mapped_column(String(200))  # e.g. "3x/week × 4 weeks"
    duration_weeks: Mapped[int | None] = mapped_column()
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)

    # Ordering physician
    physician_name: Mapped[str | None] = mapped_column(String(200))
    physician_npi: Mapped[str | None] = mapped_column(String(10))

    # Verbal order — must be followed up with written
    is_verbal_order: Mapped[bool] = mapped_column(Boolean, default=False)
    verbal_order_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    written_order_received: Mapped[bool] = mapped_column(Boolean, default=False)
    countersigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient")
