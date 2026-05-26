import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Text, JSON, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class PatientStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    discharged = "discharged"
    pending = "pending"


class InsuranceType(str, enum.Enum):
    medicare = "medicare"
    medicaid = "medicaid"
    commercial = "commercial"
    self_pay = "self_pay"


class Patient(Base):
    __tablename__ = "patients"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    mrn: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    first_name: Mapped[str] = mapped_column(String(100))
    last_name: Mapped[str] = mapped_column(String(100))
    date_of_birth: Mapped[date] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(String(20))
    phone: Mapped[str | None] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(255))
    address: Mapped[dict | None] = mapped_column(JSON)
    status: Mapped[PatientStatus] = mapped_column(SAEnum(PatientStatus), default=PatientStatus.active)
    insurance_type: Mapped[InsuranceType | None] = mapped_column(SAEnum(InsuranceType))
    insurance_id: Mapped[str | None] = mapped_column(String(100))
    primary_dx: Mapped[str | None] = mapped_column(String(500))
    diagnoses: Mapped[list | None] = mapped_column(JSON, default=list)
    medications: Mapped[list | None] = mapped_column(JSON, default=list)
    allergies: Mapped[list | None] = mapped_column(JSON, default=list)
    care_team: Mapped[list | None] = mapped_column(JSON, default=list)
    ai_risk_score: Mapped[float | None] = mapped_column()
    ai_risk_factors: Mapped[list | None] = mapped_column(JSON)
    ai_last_reviewed: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    visits: Mapped[list["Visit"]] = relationship("Visit", back_populates="patient")
    documents: Mapped[list["Document"]] = relationship("Document", back_populates="patient")
    outreach_records: Mapped[list["OutreachRecord"]] = relationship("OutreachRecord", back_populates="patient")
