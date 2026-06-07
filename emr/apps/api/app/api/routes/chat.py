"""
AI-powered clinical chat with HIPAA minimum necessary enforcement.

Every response is scoped to patients in the clinician's licensed states.
State filtering is applied at TWO independent layers:
  1. Database query: patient records are only loaded for licensed states
  2. System prompt: Claude is instructed only to discuss the pre-filtered context

This satisfies 45 CFR §164.502(b) minimum necessary standard.
"""
from __future__ import annotations
import json
import re
from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.db.base import get_db
from app.core.auth import get_current_user
from app.models.user import User, UserRole
from app.models.patient import Patient
from app.models.condition import Condition
from app.models.lab_result import LabResult
from app.models.visit import Visit

router = APIRouter(prefix="/chat", tags=["chat"])

# US state codes for validation
_US_STATES = {
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
    "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
    "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
    "VA","WA","WV","WI","WY","DC",
}

_CLINICAL_ROLES = {
    UserRole.physician, UserRole.nurse, UserRole.therapist,
    UserRole.social_worker, UserRole.aide, UserRole.care_coordinator,
}


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatMessage] = []  # recent turns for context, max 10


def _state_filter(user: User):
    """
    Return the list of states to filter by, or None if the user has org-wide access.
    Raises 403 if a clinical user has no licensed states configured.
    """
    states = [s.upper() for s in (user.licensed_states or []) if s.upper() in _US_STATES]

    if states:
        return states

    # Admins without explicit states get org-wide access (no state filter)
    if user.role in (UserRole.admin, UserRole.super_admin, UserRole.billing):
        return None

    # Clinical roles with no states configured → refuse access
    raise HTTPException(
        status_code=403,
        detail=(
            "Your account has no licensed states configured. "
            "Contact your administrator to set your licensed states before using the AI chat."
        ),
    )


async def _fetch_patient_context(
    db: AsyncSession,
    user: User,
    states: list[str] | None,
    question: str,
) -> tuple[str, list[dict]]:
    """
    Build context string for Claude. Returns (context_text, sources_list).
    Applies state filter at the DB level — PHI is never loaded for out-of-state patients.
    """
    state_expr = func.json_extract_path_text(
        Patient.address.cast(type_=None), "state"
    )

    base_q = select(Patient).where(Patient.status == "active")

    # Layer 1: DB-level state filter
    if states:
        base_q = base_q.where(state_expr.in_(states))

    # Org isolation
    if user.organization_id:
        base_q = base_q.where(Patient.organization_id == user.organization_id)

    # Check if the question mentions a specific patient (by name fragment or MRN)
    mrn_match = re.search(r"\b(CC-\d+)\b", question, re.IGNORECASE)
    name_tokens = [t for t in question.split() if len(t) >= 3 and t[0].isupper()]

    specific_patient: Patient | None = None

    if mrn_match:
        mrn = mrn_match.group(1).upper()
        r = await db.execute(base_q.where(Patient.mrn == mrn))
        specific_patient = r.scalar_one_or_none()

    if not specific_patient and name_tokens:
        # Try to find a patient whose last name appears in the question
        for token in name_tokens:
            r = await db.execute(base_q.where(Patient.last_name.ilike(f"%{token}%")))
            p = r.scalars().first()
            if p:
                specific_patient = p
                break

    sources: list[dict] = []

    if specific_patient:
        # Deep context for the specific patient
        ctx = await _build_patient_detail(db, specific_patient)
        sources.append({"type": "patient", "id": str(specific_patient.id), "name": f"{specific_patient.first_name} {specific_patient.last_name}", "mrn": specific_patient.mrn})
        return ctx, sources

    # Summary context for all in-state patients
    result = await db.execute(
        base_q.order_by(Patient.ai_risk_score.desc().nullslast()).limit(60)
    )
    patients = result.scalars().all()

    if not patients:
        state_desc = f"states: {', '.join(states)}" if states else "your organization"
        return f"No active patients found in {state_desc}.", []

    lines = [f"Active patients ({len(patients)} total, sorted by risk):"]
    for p in patients:
        risk = f"{p.ai_risk_score:.2f}" if p.ai_risk_score is not None else "unscored"
        state = (p.address or {}).get("state", "?")
        lines.append(
            f"- {p.first_name} {p.last_name} | MRN {p.mrn} | {state} | "
            f"Risk {risk} | Dx: {p.primary_dx or 'not set'} | "
            f"SOC: {p.soc_date or 'N/A'}"
        )
        sources.append({"type": "patient", "id": str(p.id), "name": f"{p.first_name} {p.last_name}", "mrn": p.mrn})

    return "\n".join(lines), sources


async def _build_patient_detail(db: AsyncSession, p: Patient) -> str:
    """Build a rich text summary for a single patient."""
    lines = [
        f"Patient: {p.first_name} {p.last_name} | MRN: {p.mrn}",
        f"DOB: {p.date_of_birth} | Gender: {p.gender or 'N/A'}",
        f"Status: {p.status} | SOC: {p.soc_date} | Cert: {p.certification_from}–{p.certification_through}",
        f"Insurance: {p.insurance_type} ({p.insurance_id})",
        f"Primary Dx: {p.primary_dx or 'not set'}",
        f"Code Status: {p.code_status or 'not set'} | Living: {p.living_situation or 'N/A'}",
        f"Risk Score: {p.ai_risk_score:.2f}" if p.ai_risk_score else "Risk Score: unscored",
    ]
    if p.baseline_weight_lbs:
        lines.append(f"Baseline weight: {p.baseline_weight_lbs} lbs")
    if p.allergies:
        lines.append(f"Allergies: {', '.join(a.get('name', str(a)) for a in (p.allergies or []))}")

    # Conditions
    cond_result = await db.execute(
        select(Condition).where(Condition.patient_id == p.id, Condition.clinical_status == "active")
    )
    conditions = cond_result.scalars().all()
    if conditions:
        lines.append("\nActive Conditions:")
        for c in conditions:
            hcc = f" [HCC {c.hcc_code}]" if c.hcc_code else ""
            lines.append(f"  - {c.icd10_code} {c.icd10_description}{hcc} ({c.verification_status})")

    # Recent labs
    lab_result = await db.execute(
        select(LabResult)
        .where(LabResult.patient_id == p.id)
        .order_by(LabResult.collected_at.desc())
        .limit(8)
    )
    labs = lab_result.scalars().all()
    if labs:
        lines.append("\nRecent Labs:")
        for l in labs:
            flag = f" [{l.interpretation}]" if l.interpretation and l.interpretation not in ("N", "normal") else ""
            val = f"{l.value_quantity} {l.unit}" if l.value_quantity is not None else (l.value_string or "")
            lines.append(f"  - {l.display_name}: {val}{flag} ({l.collected_at.date() if l.collected_at else 'N/A'})")

    # Recent visits
    visit_result = await db.execute(
        select(Visit)
        .where(Visit.patient_id == p.id)
        .order_by(Visit.scheduled_at.desc())
        .limit(5)
    )
    visits = visit_result.scalars().all()
    if visits:
        lines.append("\nRecent Visits:")
        for v in visits:
            note_snippet = ""
            if v.soap_note and isinstance(v.soap_note, dict):
                assessment = v.soap_note.get("assessment") or v.soap_note.get("a") or ""
                if assessment:
                    note_snippet = f" — A: {str(assessment)[:120]}"
            lines.append(
                f"  - {v.visit_type or 'visit'} on {v.scheduled_at.date() if v.scheduled_at else '?'} "
                f"({v.status}){note_snippet}"
            )

    return "\n".join(lines)


def _build_system_prompt(user: User, states: list[str] | None) -> str:
    state_desc = ", ".join(states) if states else "all states (org-wide access)"
    return f"""You are the ConcertoCare clinical AI assistant for {user.first_name} {user.last_name}, \
a {user.role.value.replace("_", " ")} licensed in: {state_desc}.

HIPAA MINIMUM NECESSARY ACCESS — STRICTLY ENFORCED:
The patient data provided below has been pre-filtered at the database level to ONLY include \
patients located in your licensed states ({state_desc}).
You MUST NOT speculate about, invent, or disclose any patient information outside the provided context.
If asked about a patient not in the context, respond: "I don't have a record for that patient \
in your licensed states ({state_desc}). Please verify the MRN or spelling."
Never reveal that patients exist in other states. Do not make up clinical data.

Today: {date.today().isoformat()}

When discussing patients:
- Always include their name and MRN so the clinician can verify
- Flag CRITICAL findings (interpretation HH/LL, O2 sat < 92%, HR > 110, weight gain > 2 lbs) prominently
- Be concise — clinicians need fast, actionable answers
- Suggest workflow actions when appropriate (e.g. "consider creating a task for..." or "an OASIS reassessment may be indicated")"""


@router.post("")
async def chat(
    body: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    AI chat with HIPAA minimum necessary enforcement.
    Returns a streaming Server-Sent Events response.
    """
    from app.modules.ai_engine.client import get_ai_client
    from app.core.config import get_settings
    settings = get_settings()

    if not settings.anthropic_api_key and settings.ai_provider == "anthropic":
        raise HTTPException(503, "AI service not configured (ANTHROPIC_API_KEY not set)")

    states = _state_filter(current_user)
    context, sources = await _fetch_patient_context(db, current_user, states, body.message)
    system_prompt = _build_system_prompt(current_user, states)

    # Build messages array — cap history at 10 turns
    messages = [
        {"role": m.role, "content": m.content}
        for m in body.history[-10:]
    ]
    messages.append({
        "role": "user",
        "content": f"{body.message}\n\n---\nCONTEXT (pre-filtered to your licensed states):\n{context}",
    })

    client = get_ai_client()

    async def generate():
        # Send sources metadata before streaming text
        yield f"data: {json.dumps({'type': 'sources', 'sources': sources, 'states': states or []})}\n\n"

        try:
            async with client.messages.stream(
                model=settings.ai_model,
                max_tokens=1024,
                system=system_prompt,
                messages=messages,
            ) as stream:
                async for text in stream.text_stream:
                    yield f"data: {json.dumps({'type': 'text', 'text': text})}\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'type': 'error', 'message': str(exc)})}\n\n"

        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
