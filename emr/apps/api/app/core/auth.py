"""
JWT authentication for staff and patient portal.

Staff tokens:    sub = user_id (str UUID), type = "staff"
Portal tokens:   sub = patient_id (str UUID), type = "portal"
"""
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import get_settings
from app.db.base import get_db

settings = get_settings()
_bearer = HTTPBearer(auto_error=False)


def create_access_token(
    subject: str,
    token_type: Literal["staff", "portal"] = "staff",
    expires_minutes: int | None = None,
) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=expires_minutes or settings.access_token_expire_minutes
    )
    return jwt.encode(
        {"sub": subject, "type": token_type, "exp": expire},
        settings.secret_key,
        algorithm="HS256",
    )


def _decode(token: str) -> dict:
    try:
        return jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
):
    """Dependency for staff-facing routes."""
    from app.models.user import User

    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    payload = _decode(credentials.credentials)
    if payload.get("type") != "staff":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff token required")

    result = await db.execute(select(User).where(User.id == UUID(payload["sub"])))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")
    return user


async def get_current_patient(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
):
    """Dependency for patient portal routes."""
    from app.models.patient import Patient

    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    payload = _decode(credentials.credentials)
    if payload.get("type") != "portal":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Portal token required")

    result = await db.execute(select(Patient).where(Patient.id == UUID(payload["sub"])))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Patient not found")
    return patient
