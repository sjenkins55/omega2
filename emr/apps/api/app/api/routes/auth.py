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

    token = create_access_token(str(user.id), token_type="staff")
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": f"{user.first_name} {user.last_name}",
            "role": user.role,
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

    token = create_access_token(str(patient.id), token_type="portal", expires_minutes=60 * 24 * 7)
    return {
        "access_token": token,
        "token_type": "bearer",
        "patient": {
            "id": str(patient.id),
            "mrn": patient.mrn,
            "name": f"{patient.first_name} {patient.last_name}",
            "date_of_birth": patient.date_of_birth.isoformat(),
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
