import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, JSON, ForeignKey, Boolean, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class Condition(Base):
    __tablename__ = "conditions"
    __table_args__ = (
        Index("ix_conditions_patient_icd10", "patient_id", "icd10_code"),
        Index("ix_conditions_patient_hcc", "patient_id", "hcc_code"),
        Index("ix_conditions_patient_recaptured", "patient_id", "recaptured_in_year"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    visit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), nullable=True)
    document_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("documents.id"), nullable=True)
    recaptured_visit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), nullable=True)

    icd10_code: Mapped[str | None] = mapped_column(String(20))
    icd10_description: Mapped[str] = mapped_column(String(500))
    hcc_code: Mapped[str | None] = mapped_column(String(20))
    hcc_description: Mapped[str | None] = mapped_column(String(500))

    # "active" | "resolved" | "remission"
    clinical_status: Mapped[str] = mapped_column(String(30), default="active")
    # "confirmed" | "provisional" | "refuted" — confirmed requires visit_id or document_id
    verification_status: Mapped[str] = mapped_column(String(30), default="provisional")
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)

    # "provider_entered" | "particle_health" | "fax" | "ai_suggested"
    source: Mapped[str] = mapped_column(String(50))
    recaptured_in_year: Mapped[int | None] = mapped_column(Integer, nullable=True)

    onset_date: Mapped[date | None] = mapped_column(Date)
    abatement_date: Mapped[date | None] = mapped_column(Date)
    recorded_date: Mapped[date] = mapped_column(Date)
    asserter_name: Mapped[str | None] = mapped_column(String(200))
    asserter_npi: Mapped[str | None] = mapped_column(String(10))

    raw_fhir: Mapped[dict | None] = mapped_column(JSON)
    external_id: Mapped[str | None] = mapped_column(String(255))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="conditions")
