"""
Admin routes — user management and provider territory assignment.
All endpoints are /api/v1/admin/...
"""
from __future__ import annotations
import uuid
from datetime import datetime
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, EmailStr
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
import bcrypt

from app.db.base import get_db
from app.models.user import User, UserRole
from app.models.patient import Patient
from app.models.territory import ProviderTerritory

router = APIRouter(prefix="/admin", tags=["admin"])


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    role: UserRole
    npi: str | None = None

class UserUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    role: UserRole | None = None
    npi: str | None = None
    is_active: bool | None = None
    password: str | None = None

class TerritoryAssignment(BaseModel):
    zip_codes: list[str]
    provider_id: str | None  # None = unassign

class BulkTerritoryAssignment(BaseModel):
    assignments: list[dict]  # [{zip_code, provider_id}]


# ── User management ───────────────────────────────────────────────────────────

@router.get("/users")
async def list_users(
    role: UserRole | None = None,
    is_active: bool | None = None,
    db: AsyncSession = Depends(get_db),
) -> dict:
    q = select(User)
    if role:
        q = q.where(User.role == role)
    if is_active is not None:
        q = q.where(User.is_active == is_active)
    q = q.order_by(User.last_name, User.first_name)
    result = await db.execute(q)
    users = result.scalars().all()
    return {
        "users": [_user_dict(u) for u in users],
        "count": len(users),
    }


@router.post("/users", status_code=201)
async def create_user(body: UserCreate, db: AsyncSession = Depends(get_db)) -> dict:
    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Email already in use")

    hashed = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    user = User(
        email=body.email,
        hashed_password=hashed,
        first_name=body.first_name,
        last_name=body.last_name,
        role=body.role,
        npi=body.npi,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return _user_dict(user)


@router.patch("/users/{user_id}")
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")

    if body.first_name is not None:
        user.first_name = body.first_name
    if body.last_name is not None:
        user.last_name = body.last_name
    if body.role is not None:
        user.role = body.role
    if body.npi is not None:
        user.npi = body.npi
    if body.is_active is not None:
        user.is_active = body.is_active
    if body.password:
        user.hashed_password = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()

    await db.commit()
    await db.refresh(user)
    return _user_dict(user)


@router.delete("/users/{user_id}", status_code=204)
async def deactivate_user(user_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")
    user.is_active = False
    await db.commit()


# ── Territory management ──────────────────────────────────────────────────────

@router.get("/territories")
async def list_territories(db: AsyncSession = Depends(get_db)) -> dict:
    """All zip codes that have at least one patient, with provider assignment and patient count."""
    # Count patients per zip code
    zip_counts_q = (
        select(
            func.json_extract_path_text(Patient.address.cast(type_=None), "zip").label("zip"),
            func.count(Patient.id).label("patient_count"),
        )
        .where(Patient.address.is_not(None))
        .group_by(func.json_extract_path_text(Patient.address.cast(type_=None), "zip"))
    )
    counts_result = await db.execute(zip_counts_q)
    zip_counts = {row.zip: row.patient_count for row in counts_result if row.zip}

    # Existing territory assignments
    territories_result = await db.execute(
        select(ProviderTerritory).order_by(ProviderTerritory.zip_code)
    )
    territories = {t.zip_code: t for t in territories_result.scalars().all()}

    # All zip codes = union of patients' zips and territory assignments
    all_zips = sorted(set(zip_counts.keys()) | set(territories.keys()))

    items = []
    for z in all_zips:
        t = territories.get(z)
        items.append({
            "zip_code": z,
            "patient_count": zip_counts.get(z, 0),
            "provider_id": str(t.provider_id) if t and t.provider_id else None,
            "provider_name": (
                f"{t.provider.first_name} {t.provider.last_name}"
                if t and t.provider else None
            ),
            "provider_role": t.provider.role if t and t.provider else None,
            "territory_id": str(t.id) if t else None,
        })

    # All providers (for assignment dropdown)
    providers_result = await db.execute(
        select(User).where(User.is_active == True).order_by(User.last_name)
    )
    providers = [_user_dict(u) for u in providers_result.scalars().all()]

    return {"territories": items, "total_zips": len(items), "providers": providers}


@router.get("/territories/{zip_code}/patients")
async def patients_by_zip(zip_code: str, db: AsyncSession = Depends(get_db)) -> dict:
    """Return all patients whose address.zip matches."""
    result = await db.execute(
        select(Patient).where(
            func.json_extract_path_text(Patient.address.cast(type_=None), "zip") == zip_code
        )
    )
    patients = result.scalars().all()
    return {
        "zip_code": zip_code,
        "patients": [
            {
                "id": str(p.id),
                "name": f"{p.first_name} {p.last_name}",
                "mrn": p.mrn,
                "status": p.status,
                "address": p.address,
                "ai_risk_score": p.ai_risk_score,
                "primary_dx": p.primary_dx,
            }
            for p in patients
        ],
        "count": len(patients),
    }


@router.patch("/territories/assign")
async def assign_territories(body: TerritoryAssignment, db: AsyncSession = Depends(get_db)) -> dict:
    """Assign (or unassign) a batch of zip codes to a provider."""
    provider_id = uuid.UUID(body.provider_id) if body.provider_id else None

    if provider_id:
        provider_result = await db.execute(select(User).where(User.id == provider_id))
        if not provider_result.scalar_one_or_none():
            raise HTTPException(404, "Provider not found")

    updated = []
    for zip_code in body.zip_codes:
        result = await db.execute(
            select(ProviderTerritory).where(ProviderTerritory.zip_code == zip_code)
        )
        territory = result.scalar_one_or_none()
        if territory:
            territory.provider_id = provider_id
            territory.updated_at = datetime.utcnow()
        else:
            territory = ProviderTerritory(zip_code=zip_code, provider_id=provider_id)
            db.add(territory)
        updated.append(zip_code)

    await db.commit()
    return {"updated": updated, "provider_id": body.provider_id, "count": len(updated)}


@router.get("/territories/summary")
async def territory_summary(db: AsyncSession = Depends(get_db)) -> dict:
    """Provider-centric summary: each provider and their zip codes + patient counts."""
    territories_result = await db.execute(select(ProviderTerritory))
    territories = territories_result.scalars().all()

    zip_counts_q = (
        select(
            func.json_extract_path_text(Patient.address.cast(type_=None), "zip").label("zip"),
            func.count(Patient.id).label("cnt"),
        )
        .where(Patient.address.is_not(None))
        .group_by(func.json_extract_path_text(Patient.address.cast(type_=None), "zip"))
    )
    counts_result = await db.execute(zip_counts_q)
    zip_counts = {row.zip: row.cnt for row in counts_result if row.zip}

    by_provider: dict[str, Any] = {}
    unassigned_zips = []

    for t in territories:
        if not t.provider_id:
            unassigned_zips.append({"zip_code": t.zip_code, "patient_count": zip_counts.get(t.zip_code, 0)})
            continue
        pid = str(t.provider_id)
        if pid not in by_provider:
            p = t.provider
            by_provider[pid] = {
                "provider_id": pid,
                "provider_name": f"{p.first_name} {p.last_name}" if p else "Unknown",
                "provider_role": p.role if p else None,
                "zip_codes": [],
                "total_patients": 0,
            }
        cnt = zip_counts.get(t.zip_code, 0)
        by_provider[pid]["zip_codes"].append({"zip_code": t.zip_code, "patient_count": cnt})
        by_provider[pid]["total_patients"] += cnt

    return {
        "providers": list(by_provider.values()),
        "unassigned": unassigned_zips,
    }


# ── Helpers ───────────────────────────────────────────────────────────────────

def _user_dict(u: User) -> dict:
    return {
        "id": str(u.id),
        "email": u.email,
        "first_name": u.first_name,
        "last_name": u.last_name,
        "full_name": f"{u.first_name} {u.last_name}",
        "role": u.role,
        "npi": u.npi,
        "is_active": u.is_active,
        "created_at": u.created_at.isoformat() if u.created_at else None,
    }
