import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, ForeignKey, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class ADTEvent(Base):
    """
    Admit / Discharge / Transfer events from hospital feeds.
    Inbound ADT messages trigger care coordination workflows.
    """
    __tablename__ = "adt_events"
    __table_args__ = (
        Index("ix_adt_events_patient", "patient_id"),
        Index("ix_adt_events_mrn", "mrn_in_message"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), nullable=True)

    # Raw identifiers from the sending system
    mrn_in_message: Mapped[str | None] = mapped_column(String(100))
    patient_name_in_message: Mapped[str | None] = mapped_column(String(200))

    # "admit" | "discharge" | "transfer"
    event_type: Mapped[str] = mapped_column(String(20))
    event_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    hospital_name: Mapped[str | None] = mapped_column(String(255))
    hospital_npi: Mapped[str | None] = mapped_column(String(10))
    discharge_disposition: Mapped[str | None] = mapped_column(String(100))
    admitting_diagnosis: Mapped[str | None] = mapped_column(String(500))

    # Whether we successfully matched to a Patient row
    matched: Mapped[bool] = mapped_column(Boolean, default=False)
    # Whether an outreach/workflow was auto-triggered
    workflow_triggered: Mapped[bool] = mapped_column(Boolean, default=False)

    raw_payload: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
