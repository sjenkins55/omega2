"""
Authentication endpoints for staff and patient portal.

Staff login:   POST /auth/login         → {access_token, user}
Staff me:      GET  /auth/me            → User
Portal login:  POST /auth/portal/login  → {access_token, patient}
Portal me:     GET  /auth/portal/me     → Patient summary
"""
from __future__ import annotations
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from passlib.context import CryptContext

from app.db.base import get_db
from app.core.auth import create_access_token, get_current_user, get_current_patient
from app.models.user import User
from app.models.patient import Patient

router = APIRouter(prefix="/auth", tags=["auth"])
_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ── Staff login ───────────────────────────────────────────────────────────────

class StaffLoginBody(BaseModel):
    email: str
    password: str


@router.post("/login")
async def staff_login(body: StaffLoginBody, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not user.is_active or not _pwd.verify(body.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_access_token(
        str(user.id),
        token_type="staff",
        org_id=str(user.organization_id) if user.organization_id else None,
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": f"{user.first_name} {user.last_name}",
            "role": user.role,
            "organization_id": str(user.organization_id) if user.organization_id else None,
            "is_active": user.is_active,
        },
    }


@router.get("/me")
async def staff_me(current_user: User = Depends(get_current_user)):
    u = current_user
    return {
        "id": str(u.id),
        "email": u.email,
        "full_name": f"{u.first_name} {u.last_name}",
        "role": u.role,
        "npi": u.npi,
        "is_active": u.is_active,
    }


# ── Patient portal login ──────────────────────────────────────────────────────

class PortalLoginBody(BaseModel):
    mrn: str
    date_of_birth: date  # YYYY-MM-DD


@router.post("/portal/login")
async def portal_login(body: PortalLoginBody, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Patient).where(Patient.mrn == body.mrn.strip()))
    patient = result.scalar_one_or_none()
    if not patient or patient.date_of_birth != body.date_of_birth:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="MRN or date of birth not found")

    from app.core.config import get_settings
    cfg = get_settings()
    token = create_access_token(
        str(patient.id),
        token_type="portal",
        expires_minutes=cfg.portal_token_expire_minutes,
    )
    # Return only the token — no PHI in the login response body
    return {"access_token": token, "token_type": "bearer"}


# ── Microsoft SSO ─────────────────────────────────────────────────────────────

class MicrosoftSSOBody(BaseModel):
    id_token: str


@router.post("/microsoft")
async def microsoft_sso(body: MicrosoftSSOBody, db: AsyncSession = Depends(get_db)):
    """
    Validate a Microsoft ID token and exchange it for a ConcertoCare JWT.
    The user must already exist in the EMR (created by an admin).
    Microsoft just replaces the password — authorization stays in our system.
    """
    from app.core.config import get_settings
    from app.core.microsoft_sso import validate_microsoft_id_token

    cfg = get_settings()
    if not cfg.azure_client_id:
        raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED,
                            detail="Microsoft SSO is not configured on this server")

    try:
        claims = await validate_microsoft_id_token(
            id_token=body.id_token,
            client_id=cfg.azure_client_id,
            tenant_id=cfg.azure_tenant_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    email = (claims.get("email") or claims.get("preferred_username") or "").lower().strip()
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Microsoft token did not include an email address")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"No EMR account found for {email}. Contact your administrator to create one.",
        )
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Your account has been deactivated. Contact your administrator.")

    token = create_access_token(
        str(user.id),
        token_type="staff",
        org_id=str(user.organization_id) if user.organization_id else None,
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": f"{user.first_name} {user.last_name}",
            "role": user.role,
            "organization_id": str(user.organization_id) if user.organization_id else None,
            "is_active": user.is_active,
        },
    }


@router.get("/portal/me")
async def portal_me(patient: Patient = Depends(get_current_patient)):
    return {
        "id": str(patient.id),
        "mrn": patient.mrn,
        "name": f"{patient.first_name} {patient.last_name}",
        "date_of_birth": patient.date_of_birth.isoformat() if patient.date_of_birth else None,
    }
