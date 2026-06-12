import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, ForeignKey, Float
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class VisitPhoto(Base):
    __tablename__ = "visit_photos"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    visit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("visits.id"), index=True)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("patients.id"), index=True)
    uploaded_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    s3_key: Mapped[str] = mapped_column(String(500))
    file_name: Mapped[str] = mapped_column(String(255))
    mime_type: Mapped[str] = mapped_column(String(50), default="image/jpeg")

    caption: Mapped[str | None] = mapped_column(String(500))

    # Wound tracking (optional)
    wound_location: Mapped[str | None] = mapped_column(String(200))
    # wound_type: "pressure_injury" | "surgical" | "diabetic" | "venous" | "arterial" | "other"
    wound_type: Mapped[str | None] = mapped_column(String(50))
    # measurements: {length_cm, width_cm, depth_cm, stage, tunneling_cm}
    measurements: Mapped[dict | None] = mapped_column(JSON)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
