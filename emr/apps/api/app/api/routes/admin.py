"""
Admin routes — user management, territory assignment, and organization provisioning.
All /admin/users and /admin/territories endpoints require admin or super_admin role.
/admin/organizations endpoints require super_admin role.
"""
from __future__ import annotations
import re
import uuid
import secrets
from datetime import datetime, timezone
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, EmailStr
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
import bcrypt

from app.db.base import get_db
from app.core.auth import get_current_user, require_admin, require_super_admin
from app.models.user import User, UserRole
from app.models.patient import Patient
from app.models.territory import ProviderTerritory
from app.models.organization import Organization, PlanTier

router = APIRouter(prefix="/admin", tags=["admin"])


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    role: UserRole
    npi: str | None = None
    licensed_states: list[str] = []  # e.g. ["CA", "TX"]

class UserUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    role: UserRole | None = None
    npi: str | None = None
    is_active: bool | None = None
    password: str | None = None
    licensed_states: list[str] | None = None

class TerritoryAssignment(BaseModel):
    zip_codes: list[str]
    provider_id: str | None  # None = unassign

class BulkTerritoryAssignment(BaseModel):
    assignments: list[dict]

class OrgCreate(BaseModel):
    name: str
    slug: str
    plan_tier: PlanTier = PlanTier.starter
    max_users: int | None = None
    max_patients: int | None = None

class OrgAdminCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str | None = None  # auto-generated if omitted


# ── Organization management (super_admin only) ────────────────────────────────

@router.get("/organizations")
async def list_organizations(
    current_user: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(select(Organization).order_by(Organization.created_at.desc()))
    orgs = result.scalars().all()
    return {"organizations": [_org_dict(o) for o in orgs], "count": len(orgs)}


@router.post("/organizations", status_code=201)
async def create_organization(
    body: OrgCreate,
    current_user: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    slug = re.sub(r"[^a-z0-9-]", "-", body.slug.lower().strip())
    existing = await db.execute(select(Organization).where(Organization.slug == slug))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Slug '{slug}' is already in use")

    org = Organization(
        name=body.name,
        slug=slug,
        plan_tier=body.plan_tier,
        max_users=body.max_users,
        max_patients=body.max_patients,
    )
    db.add(org)
    await db.flush()
    await db.refresh(org)
    return _org_dict(org)


@router.post("/organizations/{org_id}/provision-admin", status_code=201)
async def provision_org_admin(
    org_id: uuid.UUID,
    body: OrgAdminCreate,
    current_user: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Create the first admin user for a newly provisioned organization."""
    result = await db.execute(select(Organization).where(Organization.id == org_id))
    org = result.scalar_one_or_none()
    if not org:
        raise HTTPException(404, "Organization not found")
    if not org.is_active:
        raise HTTPException(400, "Organization is inactive")

    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Email already in use")

    password = body.password or secrets.token_urlsafe(16)
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    user = User(
        email=body.email,
        hashed_password=hashed,
        first_name=body.first_name,
        last_name=body.last_name,
        role=UserRole.admin,
        organization_id=org_id,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    result_dict = _user_dict(user)
    if not body.password:
        result_dict["generated_password"] = password  # shown once — store securely
    return result_dict


@router.patch("/organizations/{org_id}")
async def update_organization(
    org_id: uuid.UUID,
    body: dict,
    current_user: User = Depends(require_super_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(select(Organization).where(Organization.id == org_id))
    org = result.scalar_one_or_none()
    if not org:
        raise HTTPException(404, "Organization not found")
    for field in ("name", "plan_tier", "is_active", "max_users", "max_patients", "settings"):
        if field in body:
            setattr(org, field, body[field])
    await db.flush()
    await db.refresh(org)
    return _org_dict(org)


# ── User management (admin or super_admin) ────────────────────────────────────

@router.get("/users")
async def list_users(
    role: UserRole | None = None,
    is_active: bool | None = None,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    q = select(User)
    # super_admins see all users; org admins see only their org
    if current_user.role != UserRole.super_admin and current_user.organization_id:
        q = q.where(User.organization_id == current_user.organization_id)
    if role:
        q = q.where(User.role == role)
    if is_active is not None:
        q = q.where(User.is_active == is_active)
    q = q.order_by(User.last_name, User.first_name)
    result = await db.execute(q)
    users = result.scalars().all()
    return {"users": [_user_dict(u) for u in users], "count": len(users)}


@router.post("/users", status_code=201)
async def create_user(
    body: UserCreate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    # Prevent org admins from creating super_admins
    if body.role == UserRole.super_admin and current_user.role != UserRole.super_admin:
        raise HTTPException(403, "Only super admins can create super_admin accounts")

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
        licensed_states=body.licensed_states,
        organization_id=current_user.organization_id,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return _user_dict(user)


@router.patch("/users/{user_id}")
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")

    # Org admins can only manage users in their own org
    if current_user.role != UserRole.super_admin:
        if user.organization_id != current_user.organization_id:
            raise HTTPException(403, "Cannot manage users outside your organization")
        # Prevent self-promotion to super_admin or admin-via-role-change
        if body.role == UserRole.super_admin:
            raise HTTPException(403, "Only super admins can grant super_admin role")

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
    if body.licensed_states is not None:
        user.licensed_states = body.licensed_states
    if body.password:
        user.hashed_password = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()

    await db.commit()
    await db.refresh(user)
    return _user_dict(user)


@router.delete("/users/{user_id}", status_code=204)
async def deactivate_user(
    user_id: uuid.UUID,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")
    if current_user.role != UserRole.super_admin and user.organization_id != current_user.organization_id:
        raise HTTPException(403, "Cannot deactivate users outside your organization")
    user.is_active = False
    await db.commit()


# ── Territory management (admin or super_admin) ───────────────────────────────

@router.get("/territories")
async def list_territories(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
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

    territories_result = await db.execute(
        select(ProviderTerritory).order_by(ProviderTerritory.zip_code)
    )
    territories = {t.zip_code: t for t in territories_result.scalars().all()}

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

    providers_result = await db.execute(
        select(User).where(User.is_active == True).order_by(User.last_name)
    )
    providers = [_user_dict(u) for u in providers_result.scalars().all()]

    return {"territories": items, "total_zips": len(items), "providers": providers}


@router.get("/territories/{zip_code}/patients")
async def patients_by_zip(
    zip_code: str,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
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
async def assign_territories(
    body: TerritoryAssignment,
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
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
            territory.updated_at = datetime.now(timezone.utc)
        else:
            territory = ProviderTerritory(zip_code=zip_code, provider_id=provider_id)
            db.add(territory)
        updated.append(zip_code)

    await db.commit()
    return {"updated": updated, "provider_id": body.provider_id, "count": len(updated)}


@router.get("/territories/summary")
async def territory_summary(
    current_user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
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

    return {"providers": list(by_provider.values()), "unassigned": unassigned_zips}


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
        "organization_id": str(u.organization_id) if u.organization_id else None,
        "licensed_states": u.licensed_states or [],
        "created_at": u.created_at.isoformat() if u.created_at else None,
    }


def _org_dict(o: Organization) -> dict:
    return {
        "id": str(o.id),
        "name": o.name,
        "slug": o.slug,
        "plan_tier": o.plan_tier,
        "is_active": o.is_active,
        "max_users": o.max_users,
        "max_patients": o.max_patients,
        "settings": o.settings,
        "created_at": o.created_at.isoformat() if o.created_at else None,
    }
