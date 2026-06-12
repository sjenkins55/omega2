"""
Integration API — per-organization API-key access for third-party systems.

Auth:    X-API-Key header. Keys are issued per organization with scopes;
         only the SHA-256 hash is stored. All writes are stamped with the
         key's organization_id — payloads cannot write into another org.

Endpoints (bulk upsert, full field set writable):
    POST /integration/patients/upsert      — upsert by MRN within the org
    POST /integration/visits/bulk          — create visits (full clinical fields)
    POST /integration/lab-results/bulk     — create lab results
    POST /integration/conditions/bulk      — upsert conditions by external_id

Key management (staff JWT, org admin):
    GET    /integration/keys
    POST   /integration/keys               — returns the raw key ONCE
    DELETE /integration/keys/{key_id}      — revoke
"""
from __future__ import annotations

import hashlib
import secrets
from datetime import date, datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import get_db
from app.core.auth import require_admin
from app.models.integration_key import IntegrationApiKey
from app.models.patient import Patient, PatientStatus, InsuranceType
from app.models.visit import Visit, VisitType, VisitStatus
from app.models.lab_result import LabResult
from app.models.condition import Condition
from app.models.user import UserRole
from app.schemas.patient import PatientCreate

router = APIRouter(prefix="/integration", tags=["integration"])

SCOPES = {"patients:write", "visits:write", "lab_results:write", "conditions:write"}


# ── API key auth ──────────────────────────────────────────────────────────────

def _hash_key(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


async def get_api_key(
    x_api_key: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
) -> IntegrationApiKey:
    if not x_api_key:
        raise HTTPException(401, "X-API-Key header required")
    result = await db.execute(
        select(IntegrationApiKey).where(IntegrationApiKey.key_hash == _hash_key(x_api_key))
    )
    key = result.scalar_one_or_none()
    if not key or not key.is_active:
        raise HTTPException(401, "Invalid or revoked API key")
    key.last_used_at = datetime.now(timezone.utc)
    return key


def require_scope(scope: str):
    async def _check(key: IntegrationApiKey = Depends(get_api_key)) -> IntegrationApiKey:
        if scope not in (key.scopes or []):
            raise HTTPException(403, f"API key missing required scope: {scope}")
        return key
    return _check


# ── Key management (staff JWT, admin) ─────────────────────────────────────────

class KeyCreate(BaseModel):
    name: str
    scopes: list[str] = Field(default_factory=lambda: sorted(SCOPES))
    organization_id: UUID | None = None  # super_admin may issue for any org


@router.get("/keys")
async def list_keys(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    query = select(IntegrationApiKey)
    if current_user.role != UserRole.super_admin:
        query = query.where(IntegrationApiKey.organization_id == current_user.organization_id)
    result = await db.execute(query.order_by(IntegrationApiKey.created_at.desc()))
    return [
        {
            "id": str(k.id),
            "name": k.name,
            "key_prefix": k.key_prefix,
            "scopes": k.scopes,
            "is_active": k.is_active,
            "organization_id": str(k.organization_id),
            "created_at": k.created_at,
            "last_used_at": k.last_used_at,
        }
        for k in result.scalars().all()
    ]


@router.post("/keys", status_code=201)
async def create_key(
    body: KeyCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    bad = set(body.scopes) - SCOPES
    if bad:
        raise HTTPException(422, f"Unknown scopes: {sorted(bad)}")

    org_id = body.organization_id
    if org_id and org_id != current_user.organization_id and current_user.role != UserRole.super_admin:
        raise HTTPException(403, "Cannot issue keys for another organization")
    org_id = org_id or current_user.organization_id
    if not org_id:
        raise HTTPException(422, "organization_id is required")

    raw = f"ck_{secrets.token_urlsafe(32)}"
    key = IntegrationApiKey(
        organization_id=org_id,
        name=body.name,
        key_hash=_hash_key(raw),
        key_prefix=raw[:10],
        scopes=body.scopes,
        created_by_id=current_user.id,
    )
    db.add(key)
    await db.flush()
    return {
        "id": str(key.id),
        "name": key.name,
        "scopes": key.scopes,
        # Shown exactly once — store it securely
        "api_key": raw,
    }


@router.delete("/keys/{key_id}")
async def revoke_key(
    key_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    result = await db.execute(select(IntegrationApiKey).where(IntegrationApiKey.id == key_id))
    key = result.scalar_one_or_none()
    if not key or (
        current_user.role != UserRole.super_admin
        and key.organization_id != current_user.organization_id
    ):
        raise HTTPException(404, "Key not found")
    key.is_active = False
    await db.flush()
    return {"status": "revoked", "id": str(key_id)}


# ── Bulk patient upsert ───────────────────────────────────────────────────────

class PatientUpsertItem(PatientCreate):
    status: PatientStatus = PatientStatus.active


class PatientUpsertRequest(BaseModel):
    patients: list[PatientUpsertItem] = Field(max_length=500)


@router.post("/patients/upsert")
async def upsert_patients(
    body: PatientUpsertRequest,
    db: AsyncSession = Depends(get_db),
    key: IntegrationApiKey = Depends(require_scope("patients:write")),
):
    """Upsert patients by MRN within the key's organization. Every field in the
    patient schema is writable, including AI backfill fields."""
    created, updated = [], []
    for item in body.patients:
        data = item.model_dump(exclude_unset=True)
        data.pop("organization_id", None)  # always the key's org
        result = await db.execute(
            select(Patient).where(
                Patient.mrn == item.mrn,
                Patient.organization_id == key.organization_id,
            )
        )
        patient = result.scalar_one_or_none()
        if patient:
            for field, value in data.items():
                if field != "mrn":
                    setattr(patient, field, value)
            updated.append({"mrn": patient.mrn, "id": str(patient.id)})
        else:
            patient = Patient(**data, organization_id=key.organization_id)
            db.add(patient)
            await db.flush()
            created.append({"mrn": patient.mrn, "id": str(patient.id)})
    await db.flush()
    return {"created": created, "updated": updated}


# ── Bulk visits ───────────────────────────────────────────────────────────────

class VisitBulkItem(BaseModel):
    patient_mrn: str | None = None
    patient_id: UUID | None = None
    visit_type: VisitType
    status: VisitStatus | None = None
    scheduled_at: datetime | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    clinician_id: UUID | None = None
    raw_note: str | None = None
    subjective: str | None = None
    objective: str | None = None
    assessment: str | None = None
    plan: str | None = None
    structured_note: dict | None = None
    vital_signs: dict | None = None
    clinical_findings: dict | None = None
    action_items: list | None = None
    note_finalized: bool | None = None


class VisitBulkRequest(BaseModel):
    visits: list[VisitBulkItem] = Field(max_length=500)


async def _resolve_patient(db: AsyncSession, org_id, patient_id: UUID | None, mrn: str | None) -> Patient:
    if not patient_id and not mrn:
        raise HTTPException(422, "Each item needs patient_id or patient_mrn")
    query = select(Patient).where(Patient.organization_id == org_id)
    query = query.where(Patient.id == patient_id) if patient_id else query.where(Patient.mrn == mrn)
    result = await db.execute(query)
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, f"Patient not found in this organization: {patient_id or mrn}")
    return patient


@router.post("/visits/bulk")
async def bulk_create_visits(
    body: VisitBulkRequest,
    db: AsyncSession = Depends(get_db),
    key: IntegrationApiKey = Depends(require_scope("visits:write")),
):
    """Create visits with the full clinical field set — historical import friendly."""
    created = []
    for item in body.visits:
        patient = await _resolve_patient(db, key.organization_id, item.patient_id, item.patient_mrn)
        data = item.model_dump(exclude_unset=True, exclude={"patient_mrn", "patient_id"})
        visit = Visit(patient_id=patient.id, **data)
        db.add(visit)
        await db.flush()
        created.append({"id": str(visit.id), "patient_id": str(patient.id)})
    return {"created": created}


# ── Bulk lab results ──────────────────────────────────────────────────────────

class LabBulkItem(BaseModel):
    patient_mrn: str | None = None
    patient_id: UUID | None = None
    visit_id: UUID | None = None
    source: str = "integration"
    loinc_code: str | None = None
    display_name: str
    category: str | None = None
    value_quantity: float | None = None
    value_string: str | None = None
    unit: str | None = None
    reference_range_low: float | None = None
    reference_range_high: float | None = None
    interpretation: str | None = None
    status: str = "final"
    collected_at: datetime | None = None
    resulted_at: datetime | None = None
    ordering_provider: str | None = None
    performing_lab: str | None = None
    raw_fhir: dict | None = None
    external_id: str | None = None


class LabBulkRequest(BaseModel):
    lab_results: list[LabBulkItem] = Field(max_length=1000)


@router.post("/lab-results/bulk")
async def bulk_create_lab_results(
    body: LabBulkRequest,
    db: AsyncSession = Depends(get_db),
    key: IntegrationApiKey = Depends(require_scope("lab_results:write")),
):
    created = []
    for item in body.lab_results:
        patient = await _resolve_patient(db, key.organization_id, item.patient_id, item.patient_mrn)
        data = item.model_dump(exclude_unset=True, exclude={"patient_mrn", "patient_id"})
        lab = LabResult(patient_id=patient.id, **data)
        db.add(lab)
        await db.flush()
        created.append({"id": str(lab.id), "patient_id": str(patient.id)})
    return {"created": created}


# ── Bulk conditions (upsert by external_id) ──────────────────────────────────

class ConditionBulkItem(BaseModel):
    patient_mrn: str | None = None
    patient_id: UUID | None = None
    visit_id: UUID | None = None
    document_id: UUID | None = None
    icd10_code: str | None = None
    icd10_description: str
    hcc_code: str | None = None
    hcc_description: str | None = None
    clinical_status: str = "active"
    verification_status: str = "provisional"
    is_primary: bool = False
    source: str = "integration"
    onset_date: date | None = None
    abatement_date: date | None = None
    recorded_date: date | None = None
    asserter_name: str | None = None
    asserter_npi: str | None = None
    raw_fhir: dict | None = None
    external_id: str | None = None


class ConditionBulkRequest(BaseModel):
    conditions: list[ConditionBulkItem] = Field(max_length=1000)


@router.post("/conditions/bulk")
async def bulk_upsert_conditions(
    body: ConditionBulkRequest,
    db: AsyncSession = Depends(get_db),
    key: IntegrationApiKey = Depends(require_scope("conditions:write")),
):
    """Create conditions; if external_id matches an existing row for the same
    patient it is updated instead. ICD-10 codes are auto-mapped to HCC V28
    when no hcc_code is supplied."""
    from app.services.hcc_mapping import map_icd10_to_hcc

    created, updated = [], []
    for item in body.conditions:
        patient = await _resolve_patient(db, key.organization_id, item.patient_id, item.patient_mrn)
        data = item.model_dump(exclude_unset=True, exclude={"patient_mrn", "patient_id"})
        data.setdefault("recorded_date", date.today())

        if not data.get("hcc_code") and data.get("icd10_code"):
            hcc = map_icd10_to_hcc(data["icd10_code"])
            if hcc:
                data["hcc_code"] = hcc["hcc_code"]
                data["hcc_description"] = hcc["description"]

        existing = None
        if item.external_id:
            result = await db.execute(
                select(Condition).where(
                    Condition.patient_id == patient.id,
                    Condition.external_id == item.external_id,
                )
            )
            existing = result.scalar_one_or_none()

        if existing:
            for field, value in data.items():
                setattr(existing, field, value)
            updated.append({"id": str(existing.id), "external_id": item.external_id})
        else:
            cond = Condition(patient_id=patient.id, **data)
            db.add(cond)
            await db.flush()
            created.append({"id": str(cond.id), "patient_id": str(patient.id)})
    return {"created": created, "updated": updated}
