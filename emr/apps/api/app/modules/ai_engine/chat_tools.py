"""
Tool definitions + executor for the agentic clinical chat.

The chat agent can read AND write the chart: search patients, pull full
charts, find geographically-matched providers, schedule/reschedule visits,
write progress notes, update any writable patient field, create tasks,
and add diagnoses.

Security model (enforced HERE, not by the model):
  - Org isolation: every patient/visit lookup checks organization_id
  - State scoping: clinical users only touch patients in licensed states
  - Field whitelist: writes go through explicit per-model field lists
"""
from __future__ import annotations

import math
import uuid
from datetime import date, datetime, timedelta, timezone

from dateutil import parser as dtparser
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import can_access_org_row
from app.models.patient import Patient, PatientStatus, InsuranceType
from app.models.user import User, UserRole
from app.models.visit import Visit, VisitStatus, VisitType
from app.models.task import Task, TaskPriority, TaskCategory
from app.models.condition import Condition
from app.models.lab_result import LabResult

# ── Tool definitions ──────────────────────────────────────────────────────────

CHAT_TOOLS: list[dict] = [
    {
        "name": "search_patients",
        "description": (
            "Search active patients by name, MRN, city, or state. Returns id, name, MRN, "
            "address, risk score, primary dx, and assigned provider. Use this to find a "
            "patient before reading or writing their chart."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Name fragment or MRN"},
                "state": {"type": "string", "description": "Two-letter state code filter"},
                "city": {"type": "string", "description": "City filter"},
                "status": {"type": "string", "enum": ["active", "inactive", "discharged", "pending"]},
                "limit": {"type": "integer", "default": 20},
            },
        },
    },
    {
        "name": "get_patient_chart",
        "description": (
            "Read a patient's full chart: demographics, address, insurance, medications, "
            "allergies, active conditions, recent labs, recent visits, care team, episode dates."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {"patient_id": {"type": "string"}},
        },
    },
    {
        "name": "update_patient_chart",
        "description": (
            "Write to any writable field on the patient chart. Pass only the fields you want "
            "to change in `updates`. Writable: first_name, last_name, preferred_name, "
            "date_of_birth (YYYY-MM-DD), gender, phone, email, address (object), status, "
            "insurance_type, insurance_id, insurance_plan_name, primary_dx, diagnoses (list), "
            "medications (list), allergies (list), care_team (list), emergency_contact (object), "
            "code_status, living_situation, caregiver_name, caregiver_phone, baseline_weight_lbs, "
            "functional_limitations (object), advance_directives_on_file, soc_date, "
            "certification_from, certification_through, referral_source, referring_physician_name, "
            "referring_physician_npi, discharge_date, discharge_reason, assigned_provider_id, "
            "preferred_language, preferred_contact_method. "
            "For list fields (medications, allergies...) pass the COMPLETE new list — read the "
            "chart first, then write the merged result."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "updates"],
            "properties": {
                "patient_id": {"type": "string"},
                "updates": {"type": "object", "description": "Field → new value map"},
            },
        },
    },
    {
        "name": "list_providers",
        "description": (
            "List clinicians/providers in the organization: name, role, licensed states, home "
            "base city, and how many visits they have scheduled in the next 7 days (workload)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "role": {"type": "string", "description": "Filter: physician, nurse, therapist, social_worker, aide, care_coordinator"},
                "state": {"type": "string", "description": "Only providers licensed in this state"},
            },
        },
    },
    {
        "name": "find_providers_for_patient",
        "description": (
            "Geography-aware provider matching: returns providers licensed in the patient's "
            "state, ranked by driving distance from the provider's home base to the patient's "
            "home, with each provider's upcoming visit load. Use this when scheduling — pick "
            "the closest appropriately-skilled provider, or offer the top few options."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {
                "patient_id": {"type": "string"},
                "visit_type": {"type": "string", "description": "Optional: skilled_nursing, physical_therapy, occupational_therapy, speech_therapy, social_work, aide, telehealth"},
            },
        },
    },
    {
        "name": "get_schedule",
        "description": (
            "Read the visit schedule. Filter by provider, patient, and/or date range. "
            "Returns visit id, patient, provider, type, status, and scheduled time. "
            "Use before scheduling to check for conflicts."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "provider_id": {"type": "string"},
                "patient_id": {"type": "string"},
                "date_from": {"type": "string", "description": "YYYY-MM-DD (default today)"},
                "date_to": {"type": "string", "description": "YYYY-MM-DD (default +14 days)"},
            },
        },
    },
    {
        "name": "schedule_visit",
        "description": (
            "Schedule a new home visit for a patient with a provider at a specific date/time. "
            "Check the provider's schedule for conflicts first with get_schedule. Confirm "
            "details with the clinician in conversation before booking when ambiguous."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "provider_id", "visit_type", "scheduled_at"],
            "properties": {
                "patient_id": {"type": "string"},
                "provider_id": {"type": "string"},
                "visit_type": {"type": "string", "enum": ["skilled_nursing", "physical_therapy", "occupational_therapy", "speech_therapy", "social_work", "aide", "telehealth"]},
                "scheduled_at": {"type": "string", "description": "ISO datetime, e.g. 2026-06-15T10:00:00"},
            },
        },
    },
    {
        "name": "update_visit",
        "description": (
            "Update an existing visit: reschedule (scheduled_at), reassign (provider_id), "
            "change status (scheduled/in_progress/completed/cancelled/missed), or WRITE THE "
            "PROGRESS NOTE — subjective, objective, assessment, plan, raw_note, vital_signs, "
            "clinical_findings. SOAP fields are merged into the structured note automatically. "
            "Set finalize=true to lock the note and mark the visit completed."
        ),
        "input_schema": {
            "type": "object",
            "required": ["visit_id"],
            "properties": {
                "visit_id": {"type": "string"},
                "scheduled_at": {"type": "string", "description": "ISO datetime to reschedule"},
                "provider_id": {"type": "string", "description": "Reassign to this provider"},
                "status": {"type": "string", "enum": ["scheduled", "in_progress", "completed", "cancelled", "missed"]},
                "visit_type": {"type": "string"},
                "subjective": {"type": "string"},
                "objective": {"type": "string"},
                "assessment": {"type": "string"},
                "plan": {"type": "string"},
                "raw_note": {"type": "string"},
                "vital_signs": {"type": "object"},
                "clinical_findings": {"type": "object"},
                "finalize": {"type": "boolean", "default": False},
            },
        },
    },
    {
        "name": "create_task",
        "description": "Create a task/to-do, optionally tied to a patient and assigned to a provider.",
        "input_schema": {
            "type": "object",
            "required": ["title"],
            "properties": {
                "title": {"type": "string"},
                "description": {"type": "string"},
                "patient_id": {"type": "string"},
                "assigned_to_id": {"type": "string"},
                "priority": {"type": "string", "enum": ["low", "normal", "high", "urgent"], "default": "normal"},
                "category": {"type": "string", "enum": ["clinical", "administrative", "follow_up", "lab_review", "medication", "scheduling", "hcc_capture", "other"], "default": "clinical"},
                "due_in_hours": {"type": "integer", "description": "Hours from now until due"},
            },
        },
    },
    {
        "name": "add_condition",
        "description": (
            "Add a diagnosis/condition to the patient's problem list by ICD-10 code. "
            "HCC category and RAF weight are auto-mapped (CMS V28)."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "icd10_code", "description"],
            "properties": {
                "patient_id": {"type": "string"},
                "icd10_code": {"type": "string"},
                "description": {"type": "string"},
                "is_primary": {"type": "boolean", "default": False},
            },
        },
    },
]

WRITE_TOOLS = {"update_patient_chart", "schedule_visit", "update_visit", "create_task", "add_condition"}

# Fields a chat-agent write may touch on Patient
_PATIENT_WRITABLE = {
    "first_name", "last_name", "preferred_name", "date_of_birth", "gender", "phone",
    "email", "address", "status", "insurance_type", "insurance_id", "insurance_plan_name",
    "insurance_group_number", "primary_dx", "diagnoses", "medications", "allergies",
    "care_team", "emergency_contact", "code_status", "living_situation", "caregiver_name",
    "caregiver_phone", "baseline_weight_lbs", "functional_limitations",
    "advance_directives_on_file", "soc_date", "certification_from", "certification_through",
    "referral_source", "referring_physician_name", "referring_physician_npi",
    "discharge_date", "discharge_reason", "assigned_provider_id",
    "preferred_language", "preferred_contact_method",
}
_PATIENT_DATE_FIELDS = {"date_of_birth", "soc_date", "certification_from", "certification_through", "discharge_date"}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _haversine_miles(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 3958.8
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return round(2 * r * math.asin(math.sqrt(a)), 1)


def _patient_in_states(p: Patient, states: list[str] | None) -> bool:
    if states is None:
        return True
    return ((p.address or {}).get("state") or "").upper() in states


async def _load_patient(patient_id: str, db: AsyncSession, user: User, states: list[str] | None) -> Patient | dict:
    """Returns the Patient or an error dict the model can act on."""
    try:
        pid = uuid.UUID(patient_id)
    except ValueError:
        return {"error": f"'{patient_id}' is not a valid patient id — use search_patients first"}
    r = await db.execute(select(Patient).where(Patient.id == pid))
    p = r.scalar_one_or_none()
    if not p or not can_access_org_row(p.organization_id, user):
        return {"error": "Patient not found in your organization"}
    if not _patient_in_states(p, states):
        return {"error": "Patient is outside your licensed states — access denied (HIPAA minimum necessary)"}
    return p


def _patient_summary(p: Patient) -> dict:
    addr = p.address or {}
    return {
        "patient_id": str(p.id),
        "name": f"{p.first_name} {p.last_name}",
        "mrn": p.mrn,
        "dob": str(p.date_of_birth),
        "status": p.status.value if p.status else None,
        "city": addr.get("city"),
        "state": addr.get("state"),
        "primary_dx": p.primary_dx,
        "risk_score": p.ai_risk_score,
        "assigned_provider_id": str(p.assigned_provider_id) if p.assigned_provider_id else None,
    }


def _provider_summary(u: User, upcoming_visits: int = 0) -> dict:
    prefs = u.preferences or {}
    return {
        "provider_id": str(u.id),
        "name": f"{u.first_name} {u.last_name}",
        "role": u.role.value,
        "licensed_states": u.licensed_states or [],
        "home_base": prefs.get("home_city"),
        "visits_next_7_days": upcoming_visits,
    }


def _parse_dt(value: str) -> datetime:
    dt = dtparser.parse(value)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


async def _upcoming_visit_counts(db: AsyncSession, provider_ids: list[uuid.UUID]) -> dict:
    if not provider_ids:
        return {}
    now = datetime.now(timezone.utc)
    r = await db.execute(
        select(Visit.clinician_id, func.count(Visit.id))
        .where(
            Visit.clinician_id.in_(provider_ids),
            Visit.status == VisitStatus.scheduled,
            Visit.scheduled_at >= now,
            Visit.scheduled_at <= now + timedelta(days=7),
        )
        .group_by(Visit.clinician_id)
    )
    return {row[0]: row[1] for row in r.all()}


# Role → visit types they can perform
_ROLE_VISIT_TYPES = {
    UserRole.nurse: {"skilled_nursing", "telehealth"},
    UserRole.physician: {"skilled_nursing", "telehealth"},
    UserRole.therapist: {"physical_therapy", "occupational_therapy", "speech_therapy", "telehealth"},
    UserRole.social_worker: {"social_work", "telehealth"},
    UserRole.aide: {"aide"},
    UserRole.care_coordinator: {"telehealth"},
}


# ── Executor ──────────────────────────────────────────────────────────────────

async def execute_chat_tool(
    name: str,
    tool_input: dict,
    db: AsyncSession,
    user: User,
    states: list[str] | None,
) -> dict:
    """Execute one tool call. Never raises — returns {"error": ...} so the agent can recover."""
    try:
        handler = _HANDLERS.get(name)
        if not handler:
            return {"error": f"Unknown tool: {name}"}
        return await handler(tool_input, db, user, states)
    except Exception as exc:  # surface to the model, don't kill the stream
        return {"error": f"{type(exc).__name__}: {exc}"}


async def _t_search_patients(inp, db, user, states):
    q = select(Patient)
    if user.role != UserRole.super_admin:
        q = q.where((Patient.organization_id == user.organization_id) | (Patient.organization_id.is_(None)))
    status = inp.get("status", "active")
    if status:
        q = q.where(Patient.status == PatientStatus(status))
    query = (inp.get("query") or "").strip()
    if query:
        like = f"%{query}%"
        q = q.where(
            (Patient.first_name.ilike(like)) | (Patient.last_name.ilike(like)) | (Patient.mrn.ilike(like))
        )
    r = await db.execute(q.order_by(Patient.ai_risk_score.desc().nullslast()).limit(400))
    patients = [p for p in r.scalars().all() if _patient_in_states(p, states)]
    if inp.get("state"):
        patients = [p for p in patients if ((p.address or {}).get("state") or "").upper() == inp["state"].upper()]
    if inp.get("city"):
        patients = [p for p in patients if inp["city"].lower() in ((p.address or {}).get("city") or "").lower()]
    limit = min(int(inp.get("limit") or 20), 50)
    return {"count": len(patients), "patients": [_patient_summary(p) for p in patients[:limit]]}


async def _t_get_patient_chart(inp, db, user, states):
    p = await _load_patient(inp["patient_id"], db, user, states)
    if isinstance(p, dict):
        return p

    conds = (await db.execute(
        select(Condition).where(Condition.patient_id == p.id, Condition.clinical_status == "active")
    )).scalars().all()
    labs = (await db.execute(
        select(LabResult).where(LabResult.patient_id == p.id).order_by(LabResult.collected_at.desc()).limit(8)
    )).scalars().all()
    visits = (await db.execute(
        select(Visit).where(Visit.patient_id == p.id).order_by(Visit.scheduled_at.desc()).limit(6)
    )).scalars().all()

    provider = None
    if p.assigned_provider_id:
        u = (await db.execute(select(User).where(User.id == p.assigned_provider_id))).scalar_one_or_none()
        if u:
            provider = _provider_summary(u)

    return {
        **_patient_summary(p),
        "gender": p.gender,
        "phone": p.phone,
        "email": p.email,
        "address": p.address,
        "insurance": {"type": p.insurance_type.value if p.insurance_type else None, "id": p.insurance_id, "plan": p.insurance_plan_name},
        "code_status": p.code_status,
        "living_situation": p.living_situation,
        "caregiver": {"name": p.caregiver_name, "phone": p.caregiver_phone},
        "baseline_weight_lbs": p.baseline_weight_lbs,
        "functional_limitations": p.functional_limitations,
        "episode": {"soc_date": str(p.soc_date) if p.soc_date else None,
                    "certification_from": str(p.certification_from) if p.certification_from else None,
                    "certification_through": str(p.certification_through) if p.certification_through else None},
        "medications": p.medications or [],
        "allergies": p.allergies or [],
        "care_team": p.care_team or [],
        "assigned_provider": provider,
        "risk_factors": p.ai_risk_factors or [],
        "conditions": [
            {"icd10": c.icd10_code, "description": c.icd10_description, "hcc": c.hcc_code,
             "verification": c.verification_status, "is_primary": c.is_primary}
            for c in conds
        ],
        "recent_labs": [
            {"name": l.display_name, "value": l.value_quantity if l.value_quantity is not None else l.value_string,
             "unit": l.unit, "flag": l.interpretation,
             "collected": str(l.collected_at.date()) if l.collected_at else None}
            for l in labs
        ],
        "recent_visits": [
            {"visit_id": str(v.id), "type": v.visit_type.value, "status": v.status.value,
             "scheduled_at": v.scheduled_at.isoformat() if v.scheduled_at else None,
             "assessment": v.assessment}
            for v in visits
        ],
    }


async def _t_update_patient_chart(inp, db, user, states):
    p = await _load_patient(inp["patient_id"], db, user, states)
    if isinstance(p, dict):
        return p
    updates = inp.get("updates") or {}
    applied, rejected = [], []
    for field, value in updates.items():
        if field not in _PATIENT_WRITABLE:
            rejected.append(field)
            continue
        if field in _PATIENT_DATE_FIELDS and isinstance(value, str):
            value = dtparser.parse(value).date()
        elif field == "status" and isinstance(value, str):
            value = PatientStatus(value)
        elif field == "insurance_type" and isinstance(value, str):
            value = InsuranceType(value)
        elif field == "assigned_provider_id" and isinstance(value, str):
            value = uuid.UUID(value)
        setattr(p, field, value)
        applied.append(field)
    p.updated_at = datetime.now(timezone.utc)
    await db.flush()
    out = {"ok": True, "patient_id": str(p.id), "updated_fields": applied}
    if rejected:
        out["rejected_fields"] = rejected
    return out


async def _t_list_providers(inp, db, user, states):
    q = select(User).where(User.is_active.is_(True), User.role != UserRole.super_admin)
    if user.role != UserRole.super_admin:
        q = q.where(User.organization_id == user.organization_id)
    if inp.get("role"):
        q = q.where(User.role == UserRole(inp["role"]))
    providers = (await db.execute(q)).scalars().all()
    if inp.get("state"):
        st = inp["state"].upper()
        providers = [u for u in providers if st in [s.upper() for s in (u.licensed_states or [])]]
    counts = await _upcoming_visit_counts(db, [u.id for u in providers])
    return {"providers": [_provider_summary(u, counts.get(u.id, 0)) for u in providers]}


async def _t_find_providers_for_patient(inp, db, user, states):
    p = await _load_patient(inp["patient_id"], db, user, states)
    if isinstance(p, dict):
        return p
    addr = p.address or {}
    pstate = (addr.get("state") or "").upper()
    plat, plng = addr.get("lat"), addr.get("lng")

    q = select(User).where(User.is_active.is_(True), User.role != UserRole.super_admin)
    if user.role != UserRole.super_admin:
        q = q.where(User.organization_id == user.organization_id)
    providers = (await db.execute(q)).scalars().all()

    visit_type = inp.get("visit_type")
    matched = []
    for u in providers:
        if pstate and pstate not in [s.upper() for s in (u.licensed_states or [])]:
            continue
        if visit_type and u.role in _ROLE_VISIT_TYPES and visit_type not in _ROLE_VISIT_TYPES[u.role]:
            continue
        prefs = u.preferences or {}
        dist = None
        if plat is not None and plng is not None and prefs.get("home_lat") is not None:
            dist = _haversine_miles(plat, plng, prefs["home_lat"], prefs["home_lng"])
        matched.append((u, dist))

    matched.sort(key=lambda t: (t[1] is None, t[1] or 0))
    counts = await _upcoming_visit_counts(db, [u.id for u, _ in matched])
    return {
        "patient_location": {"city": addr.get("city"), "state": pstate},
        "providers": [
            {**_provider_summary(u, counts.get(u.id, 0)), "distance_miles": dist}
            for u, dist in matched[:10]
        ],
    }


async def _t_get_schedule(inp, db, user, states):
    date_from = dtparser.parse(inp["date_from"]).replace(tzinfo=timezone.utc) if inp.get("date_from") else datetime.now(timezone.utc).replace(hour=0, minute=0)
    date_to = dtparser.parse(inp["date_to"]).replace(tzinfo=timezone.utc) + timedelta(days=1) if inp.get("date_to") else date_from + timedelta(days=14)

    q = (
        select(Visit, Patient, User)
        .join(Patient, Visit.patient_id == Patient.id)
        .outerjoin(User, Visit.clinician_id == User.id)
        .where(Visit.scheduled_at >= date_from, Visit.scheduled_at < date_to)
    )
    if user.role != UserRole.super_admin:
        q = q.where((Patient.organization_id == user.organization_id) | (Patient.organization_id.is_(None)))
    if inp.get("provider_id"):
        q = q.where(Visit.clinician_id == uuid.UUID(inp["provider_id"]))
    if inp.get("patient_id"):
        q = q.where(Visit.patient_id == uuid.UUID(inp["patient_id"]))
    rows = (await db.execute(q.order_by(Visit.scheduled_at).limit(100))).all()

    visits = []
    for v, p, u in rows:
        if not _patient_in_states(p, states):
            continue
        visits.append({
            "visit_id": str(v.id),
            "scheduled_at": v.scheduled_at.isoformat() if v.scheduled_at else None,
            "type": v.visit_type.value,
            "status": v.status.value,
            "patient": f"{p.first_name} {p.last_name}",
            "patient_id": str(p.id),
            "provider": f"{u.first_name} {u.last_name}" if u else None,
            "provider_id": str(u.id) if u else None,
        })
    return {"count": len(visits), "visits": visits}


async def _t_schedule_visit(inp, db, user, states):
    p = await _load_patient(inp["patient_id"], db, user, states)
    if isinstance(p, dict):
        return p
    provider = (await db.execute(select(User).where(User.id == uuid.UUID(inp["provider_id"])))).scalar_one_or_none()
    if not provider or (user.role != UserRole.super_admin and provider.organization_id != user.organization_id):
        return {"error": "Provider not found in your organization"}

    scheduled_at = _parse_dt(inp["scheduled_at"])
    # Conflict check: same provider within ±45 min
    conflict = (await db.execute(
        select(Visit).where(
            Visit.clinician_id == provider.id,
            Visit.status == VisitStatus.scheduled,
            Visit.scheduled_at >= scheduled_at - timedelta(minutes=45),
            Visit.scheduled_at <= scheduled_at + timedelta(minutes=45),
        )
    )).scalars().first()
    if conflict:
        return {
            "error": "Scheduling conflict",
            "detail": f"{provider.first_name} {provider.last_name} already has a visit at "
                      f"{conflict.scheduled_at.isoformat()}. Pick another time or provider.",
        }

    visit = Visit(
        patient_id=p.id,
        clinician_id=provider.id,
        visit_type=VisitType(inp["visit_type"]),
        status=VisitStatus.scheduled,
        scheduled_at=scheduled_at,
    )
    db.add(visit)
    await db.flush()
    return {
        "ok": True,
        "visit_id": str(visit.id),
        "patient": f"{p.first_name} {p.last_name}",
        "provider": f"{provider.first_name} {provider.last_name}",
        "visit_type": visit.visit_type.value,
        "scheduled_at": scheduled_at.isoformat(),
    }


async def _t_update_visit(inp, db, user, states):
    try:
        vid = uuid.UUID(inp["visit_id"])
    except ValueError:
        return {"error": f"'{inp['visit_id']}' is not a valid visit id"}
    row = (await db.execute(
        select(Visit, Patient).join(Patient, Visit.patient_id == Patient.id).where(Visit.id == vid)
    )).first()
    if not row or not can_access_org_row(row[1].organization_id, user):
        return {"error": "Visit not found in your organization"}
    visit, patient = row
    if not _patient_in_states(patient, states):
        return {"error": "Patient is outside your licensed states — access denied"}

    changed = []
    if inp.get("scheduled_at"):
        visit.scheduled_at = _parse_dt(inp["scheduled_at"])
        changed.append("scheduled_at")
    if inp.get("provider_id"):
        visit.clinician_id = uuid.UUID(inp["provider_id"])
        changed.append("provider")
    if inp.get("status"):
        visit.status = VisitStatus(inp["status"])
        changed.append("status")
    if inp.get("visit_type"):
        visit.visit_type = VisitType(inp["visit_type"])
        changed.append("visit_type")

    for f in ("subjective", "objective", "assessment", "plan", "raw_note"):
        if inp.get(f) is not None:
            setattr(visit, f, inp[f])
            changed.append(f)
    if inp.get("vital_signs") is not None:
        visit.vital_signs = inp["vital_signs"]
        changed.append("vital_signs")
    if inp.get("clinical_findings") is not None:
        visit.clinical_findings = inp["clinical_findings"]
        changed.append("clinical_findings")

    # Keep structured_note in sync with SOAP fields
    if any(inp.get(f) is not None for f in ("subjective", "objective", "assessment", "plan")):
        note = dict(visit.structured_note or {})
        for f in ("subjective", "objective", "assessment", "plan"):
            if inp.get(f) is not None:
                note[f] = inp[f]
        visit.structured_note = note

    if inp.get("finalize"):
        visit.status = VisitStatus.completed
        visit.completed_at = datetime.now(timezone.utc)
        visit.note_finalized = True
        changed.append("finalized")

    visit.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return {"ok": True, "visit_id": str(visit.id), "changed": changed,
            "patient": f"{patient.first_name} {patient.last_name}"}


async def _t_create_task(inp, db, user, states):
    patient_id = None
    if inp.get("patient_id"):
        p = await _load_patient(inp["patient_id"], db, user, states)
        if isinstance(p, dict):
            return p
        patient_id = p.id
    due_at = None
    if inp.get("due_in_hours"):
        due_at = datetime.now(timezone.utc) + timedelta(hours=int(inp["due_in_hours"]))
    task = Task(
        title=inp["title"],
        description=inp.get("description"),
        patient_id=patient_id,
        assigned_to_id=uuid.UUID(inp["assigned_to_id"]) if inp.get("assigned_to_id") else user.id,
        created_by_id=user.id,
        priority=TaskPriority(inp.get("priority", "normal")),
        category=TaskCategory(inp.get("category", "clinical")),
        due_at=due_at,
    )
    db.add(task)
    await db.flush()
    return {"ok": True, "task_id": str(task.id), "title": task.title}


async def _t_add_condition(inp, db, user, states):
    from app.services.hcc_mapping import map_icd10_to_hcc

    p = await _load_patient(inp["patient_id"], db, user, states)
    if isinstance(p, dict):
        return p
    code = inp["icd10_code"].upper().strip()
    hcc = map_icd10_to_hcc(code)
    cond = Condition(
        patient_id=p.id,
        icd10_code=code,
        icd10_description=inp["description"],
        hcc_code=hcc["hcc_code"] if hcc else None,
        hcc_description=hcc["description"] if hcc else None,
        clinical_status="active",
        verification_status="provisional",
        is_primary=bool(inp.get("is_primary")),
        source="ai_chat",
        recorded_date=date.today(),
        asserter_name=f"{user.first_name} {user.last_name}",
    )
    db.add(cond)
    await db.flush()
    return {
        "ok": True, "condition_id": str(cond.id), "icd10": code,
        "hcc_mapped": hcc,
        "note": "Added as provisional — confirm via the conditions workflow",
    }


_HANDLERS = {
    "search_patients": _t_search_patients,
    "get_patient_chart": _t_get_patient_chart,
    "update_patient_chart": _t_update_patient_chart,
    "list_providers": _t_list_providers,
    "find_providers_for_patient": _t_find_providers_for_patient,
    "get_schedule": _t_get_schedule,
    "schedule_visit": _t_schedule_visit,
    "update_visit": _t_update_visit,
    "create_task": _t_create_task,
    "add_condition": _t_add_condition,
}
