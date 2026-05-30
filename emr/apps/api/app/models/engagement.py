import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, JSON, ForeignKey, Enum as SAEnum, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class OutreachChannel(str, enum.Enum):
    phone = "phone"
    sms = "sms"
    email = "email"
    portal = "portal"


class OutreachStatus(str, enum.Enum):
    scheduled = "scheduled"
    sent = "sent"
    delivered = "delivered"
    failed = "failed"
    responded = "responded"
    no_response = "no_response"


class OutreachType(str, enum.Enum):
    appointment_reminder = "appointment_reminder"
    medication_check = "medication_check"
    care_gap_closure = "care_gap_closure"
    welcome = "welcome"
    discharge_followup = "discharge_followup"
    annual_wellness = "annual_wellness"
    custom = "custom"


class OutreachRecord(Base):
    __tablename__ = "outreach_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)

    outreach_type: Mapped[OutreachType] = mapped_column(SAEnum(OutreachType))
    channel: Mapped[OutreachChannel] = mapped_column(SAEnum(OutreachChannel))
    status: Mapped[OutreachStatus] = mapped_column(SAEnum(OutreachStatus), default=OutreachStatus.scheduled)

    # AI-generated message content
    message_template: Mapped[str | None] = mapped_column(String(100))
    message_content: Mapped[str | None] = mapped_column(Text)
    ai_personalized: Mapped[bool] = mapped_column(Boolean, default=False)

    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    response_received_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    response_content: Mapped[str | None] = mapped_column(Text)

    workflow_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("workflows.id"))
    extra_data: Mapped[dict | None] = mapped_column(JSON)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient", back_populates="outreach_records")
