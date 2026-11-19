import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, JSON, ForeignKey, Enum as SAEnum, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class DocumentType(str, enum.Enum):
    fax = "fax"
    lab_result = "lab_result"
    discharge_summary = "discharge_summary"
    referral = "referral"
    order = "order"
    insurance = "insurance"
    consent = "consent"
    care_plan = "care_plan"
    other = "other"


class DocumentStatus(str, enum.Enum):
    received = "received"
    processing = "processing"
    classified = "classified"
    indexed = "indexed"
    failed = "failed"


class Document(Base):
    __tablename__ = "documents"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)

    doc_type: Mapped[DocumentType] = mapped_column(SAEnum(DocumentType), default=DocumentType.other)
    status: Mapped[DocumentStatus] = mapped_column(SAEnum(DocumentStatus), default=DocumentStatus.received)

    source: Mapped[str | None] = mapped_column(String(255))
    source_fax_number: Mapped[str | None] = mapped_column(String(20))
    sender_name: Mapped[str | None] = mapped_column(String(255))

    file_name: Mapped[str] = mapped_column(String(500))
    s3_key: Mapped[str] = mapped_column(String(1000))
    mime_type: Mapped[str] = mapped_column(String(100))
    page_count: Mapped[int | None] = mapped_column()

    raw_text: Mapped[str | None] = mapped_column(Text)
    extracted_data: Mapped[dict | None] = mapped_column(JSON)
    ai_summary: Mapped[str | None] = mapped_column(Text)
    ai_classifications: Mapped[list | None] = mapped_column(JSON)

    requires_action: Mapped[bool] = mapped_column(Boolean, default=False)
    action_taken: Mapped[bool] = mapped_column(Boolean, default=False)
    triggered_workflows: Mapped[list | None] = mapped_column(JSON, default=list)

    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="documents")
