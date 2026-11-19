import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Text, JSON, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class PlanOfCare(Base):
    """CMS Form 485 — Home Health Certification and Plan of Care."""
    __tablename__ = "plans_of_care"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # Certification period
    cert_from: Mapped[date | None] = mapped_column(Date)
    cert_through: Mapped[date | None] = mapped_column(Date)

    # Diagnoses
    primary_diagnosis_code: Mapped[str | None] = mapped_column(String(20))
    primary_diagnosis_desc: Mapped[str | None] = mapped_column(String(500))
    secondary_diagnoses: Mapped[list | None] = mapped_column(JSON, default=list)

    # Orders (references physician_orders rows, also summarized here)
    skilled_nursing_orders: Mapped[str | None] = mapped_column(Text)
    therapy_orders: Mapped[str | None] = mapped_column(Text)
    medications: Mapped[list | None] = mapped_column(JSON, default=list)

    # Goals / functional
    goals: Mapped[str | None] = mapped_column(Text)
    functional_limitations: Mapped[list | None] = mapped_column(JSON, default=list)
    activities_permitted: Mapped[list | None] = mapped_column(JSON, default=list)
    safety_measures: Mapped[str | None] = mapped_column(Text)
    nutritional_requirements: Mapped[str | None] = mapped_column(Text)

    # Physician signature
    physician_name: Mapped[str | None] = mapped_column(String(200))
    physician_npi: Mapped[str | None] = mapped_column(String(10))
    physician_address: Mapped[str | None] = mapped_column(String(500))
    physician_phone: Mapped[str | None] = mapped_column(String(20))

    # "pending" | "sent_for_signature" | "signed" | "expired"
    signature_status: Mapped[str] = mapped_column(String(30), default="pending")
    signed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    signature_document_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    # "draft" | "active" | "superseded" | "expired"
    status: Mapped[str] = mapped_column(String(20), default="draft")

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient")
