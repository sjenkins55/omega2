import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, JSON, ForeignKey, Enum as SAEnum, Boolean, Float, Index, Integer, UniqueConstraint
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
    __table_args__ = (
        Index("ix_patients_assigned_provider", "assigned_provider_id"),
        Index("ix_patients_status", "status"),
        Index("ix_patients_soc_date", "soc_date"),
        Index("ix_patients_risk_score", "ai_risk_score"),
        Index("ix_patients_org", "organization_id"),
        # MRN is unique per organization, not globally — each agency has its own numbering
        UniqueConstraint("mrn", "organization_id", name="uq_patient_mrn_org"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    mrn: Mapped[str] = mapped_column(String(50), index=True)
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

    # Demographics
    preferred_name: Mapped[str | None] = mapped_column(String(100))
    preferred_language: Mapped[str | None] = mapped_column(String(10))
    preferred_contact_method: Mapped[str | None] = mapped_column(String(20))
    emergency_contact: Mapped[dict | None] = mapped_column(JSON)

    # Multi-tenancy
    organization_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=True)

    # Clinician assignment
    assigned_provider_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # Home care episode
    soc_date: Mapped[date | None] = mapped_column(Date)
    certification_from: Mapped[date | None] = mapped_column(Date)
    certification_through: Mapped[date | None] = mapped_column(Date)
    referral_source: Mapped[str | None] = mapped_column(String(255))
    referring_physician_name: Mapped[str | None] = mapped_column(String(200))
    referring_physician_npi: Mapped[str | None] = mapped_column(String(10))
    discharge_date: Mapped[date | None] = mapped_column(Date)
    discharge_reason: Mapped[str | None] = mapped_column(String(255))

    # Clinical context
    code_status: Mapped[str | None] = mapped_column(String(30))
    living_situation: Mapped[str | None] = mapped_column(String(30))
    caregiver_name: Mapped[str | None] = mapped_column(String(200))
    caregiver_phone: Mapped[str | None] = mapped_column(String(20))
    baseline_weight_lbs: Mapped[float | None] = mapped_column(Float)
    functional_limitations: Mapped[dict | None] = mapped_column(JSON)
    advance_directives_on_file: Mapped[bool] = mapped_column(Boolean, default=False)

    # Insurance
    insurance_plan_name: Mapped[str | None] = mapped_column(String(200))
    insurance_group_number: Mapped[str | None] = mapped_column(String(100))
    secondary_insurance_type: Mapped[InsuranceType | None] = mapped_column(SAEnum(InsuranceType))
    secondary_insurance_id: Mapped[str | None] = mapped_column(String(100))

    visits: Mapped[list["Visit"]] = relationship("Visit", back_populates="patient")
    documents: Mapped[list["Document"]] = relationship("Document", back_populates="patient")
    outreach_records: Mapped[list["OutreachRecord"]] = relationship("OutreachRecord", back_populates="patient")
    assigned_provider: Mapped["User | None"] = relationship("User", foreign_keys=[assigned_provider_id])
    organization: Mapped["Organization | None"] = relationship("Organization", back_populates="patients")
    conditions: Mapped[list["Condition"]] = relationship("Condition", back_populates="patient")
    lab_results: Mapped[list["LabResult"]] = relationship("LabResult", back_populates="patient")
