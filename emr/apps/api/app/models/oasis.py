import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, JSON, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from app.db.base import Base


class OasisType(str, enum.Enum):
    SOC = "SOC"    # Start of Care
    ROC = "ROC"    # Resumption of Care
    FU = "FU"      # Follow-up
    REC = "REC"    # Recertification
    DC = "DC"      # Discharge


class OasisStatus(str, enum.Enum):
    draft = "draft"
    complete = "complete"
    submitted = "submitted"
    locked = "locked"


class OasisAssessment(Base):
    """
    OASIS-E assessment (mandated by CMS for Medicare-certified home health).
    Key sections stored as typed JSON for flexibility across OASIS versions.
    """
    __tablename__ = "oasis_assessments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    visit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), nullable=True)
    completed_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    assessment_type: Mapped[OasisType] = mapped_column()
    status: Mapped[OasisStatus] = mapped_column(default=OasisStatus.draft)
    assessment_date: Mapped[date | None] = mapped_column(Date)

    # M0010–M0069: Patient Tracking Information
    # Stored as flat JSON: {m0010_agency_cms_id, m0014_branch_id, m0016_branch_state, ...}
    section_m0: Mapped[dict | None] = mapped_column(JSON)

    # M1000–M1062: Therapy Need & Influenza/Pneumo Vaccines
    section_m1: Mapped[dict | None] = mapped_column(JSON)

    # M1100–M1242: Living Arrangements & Supportive Assistance
    section_living: Mapped[dict | None] = mapped_column(JSON)

    # M1300–M1350: Health Conditions (pressure ulcers, surgical wounds, etc.)
    section_health: Mapped[dict | None] = mapped_column(JSON)

    # M1400–M1600: Sensory, Integumentary, Respiratory, Elimination Status
    section_clinical: Mapped[dict | None] = mapped_column(JSON)

    # M1700–M1870: Cognitive / Behavioral / Emotional Status (PHQ-2, BIMS)
    section_cognitive: Mapped[dict | None] = mapped_column(JSON)

    # M1900–M2030: ADL/IADLs (bathing, dressing, ambulation, medication mgmt)
    section_functional: Mapped[dict | None] = mapped_column(JSON)

    # M2100–M2250: Care Management, Discharge, Emergent Care
    section_care_mgmt: Mapped[dict | None] = mapped_column(JSON)

    # GG items: Functional Abilities and Goals (PDGM grouping input)
    section_gg: Mapped[dict | None] = mapped_column(JSON)

    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    iqies_submission_id: Mapped[str | None] = mapped_column(String(100))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    patient: Mapped["Patient"] = relationship("Patient")
