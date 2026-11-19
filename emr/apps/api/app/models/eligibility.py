import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class EligibilityCheck(Base):
    __tablename__ = "eligibility_checks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    checked_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    payer_name: Mapped[str | None] = mapped_column(String(200))
    payer_id: Mapped[str | None] = mapped_column(String(100))
    insurance_id: Mapped[str | None] = mapped_column(String(100))
    insurance_type: Mapped[str | None] = mapped_column(String(50))

    # Result
    coverage_active: Mapped[bool | None] = mapped_column(Boolean)
    # coverage_dates: {start, end}
    coverage_dates: Mapped[dict | None] = mapped_column(JSON)
    # benefits: {home_health_covered, visits_remaining, copay, deductible_met, deductible_total}
    benefits: Mapped[dict | None] = mapped_column(JSON)
    # errors or notes from the clearinghouse
    notes: Mapped[str | None] = mapped_column(String(1000))
    raw_response: Mapped[dict | None] = mapped_column(JSON)

    checked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
