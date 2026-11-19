import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, Boolean, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class IntegrationApiKey(Base):
    """Per-organization API key for third-party integrations.

    The raw key is shown once at creation; only a SHA-256 hash is stored.
    Every write made with a key is stamped with the key's organization_id,
    so cross-org writes are impossible regardless of payload contents.
    """
    __tablename__ = "integration_api_keys"
    __table_args__ = (
        Index("ix_integration_keys_org", "organization_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("organizations.id"))
    name: Mapped[str] = mapped_column(String(200))
    key_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    # First 8 chars of the raw key, for display ("ck_a1b2c3…")
    key_prefix: Mapped[str] = mapped_column(String(12))
    # e.g. ["patients:write", "visits:write", "lab_results:write", "conditions:write"]
    scopes: Mapped[list] = mapped_column(JSON, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    organization = relationship("Organization")
