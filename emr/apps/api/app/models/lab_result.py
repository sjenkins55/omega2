import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, Float, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class LabResult(Base):
    __tablename__ = "lab_results"
    __table_args__ = (
        Index("ix_lab_results_patient_loinc_collected", "patient_id", "loinc_code", "collected_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    visit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), nullable=True)

    # "particle_health" | "fax" | "manual" | "healthlake"
    source: Mapped[str] = mapped_column(String(50))

    loinc_code: Mapped[str | None] = mapped_column(String(20))
    display_name: Mapped[str] = mapped_column(String(255))
    # "laboratory" | "vital-signs" | "imaging"
    category: Mapped[str | None] = mapped_column(String(50))

    value_quantity: Mapped[float | None] = mapped_column(Float)
    value_string: Mapped[str | None] = mapped_column(String(500))
    unit: Mapped[str | None] = mapped_column(String(50))
    reference_range_low: Mapped[float | None] = mapped_column(Float)
    reference_range_high: Mapped[float | None] = mapped_column(Float)
    # "H" | "L" | "N" | "HH" | "LL"
    interpretation: Mapped[str | None] = mapped_column(String(10))
    # "final" | "preliminary" | "corrected"
    status: Mapped[str] = mapped_column(String(20), default="final")

    collected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    resulted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ordering_provider: Mapped[str | None] = mapped_column(String(200))
    performing_lab: Mapped[str | None] = mapped_column(String(255))

    raw_fhir: Mapped[dict | None] = mapped_column(JSON)
    external_id: Mapped[str | None] = mapped_column(String(255))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="lab_results")
