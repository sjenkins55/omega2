import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, Index
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class AuditEvent(Base):
    """HIPAA-required audit log — append-only, never updated or deleted."""
    __tablename__ = "audit_events"
    __table_args__ = (
        Index("ix_audit_events_user", "user_id"),
        Index("ix_audit_events_resource", "resource_type", "resource_id"),
        Index("ix_audit_events_created", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    user_email: Mapped[str | None] = mapped_column(String(255))

    # action: "read" | "create" | "update" | "delete" | "login" | "export"
    action: Mapped[str] = mapped_column(String(50))
    resource_type: Mapped[str] = mapped_column(String(100))  # "patient" | "visit" | "document" ...
    resource_id: Mapped[str | None] = mapped_column(String(255))

    ip_address: Mapped[str | None] = mapped_column(String(45))
    user_agent: Mapped[str | None] = mapped_column(String(500))
    extra: Mapped[dict | None] = mapped_column(JSON)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, index=True)
