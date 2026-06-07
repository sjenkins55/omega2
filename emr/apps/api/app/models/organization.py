import uuid
import enum
from datetime import datetime
from sqlalchemy import String, Boolean, Integer, Enum as SAEnum, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base


class PlanTier(str, enum.Enum):
    starter = "starter"
    professional = "professional"
    enterprise = "enterprise"


class Organization(Base):
    __tablename__ = "organizations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    plan_tier: Mapped[PlanTier] = mapped_column(SAEnum(PlanTier, name="plan_tier"), default=PlanTier.starter)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    max_users: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_patients: Mapped[int | None] = mapped_column(Integer, nullable=True)
    settings: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow, nullable=False)

    users: Mapped[list["User"]] = relationship("User", back_populates="organization")
    patients: Mapped[list["Patient"]] = relationship("Patient", back_populates="organization")
