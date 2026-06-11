"""
Agentic AI clinical chat with HIPAA minimum necessary enforcement.

The agent has real tools: it can search/read charts, find providers by
geography, schedule and reschedule visits conversationally, write progress
notes, update any writable chart field, create tasks, and add diagnoses.

Security is enforced in the TOOL EXECUTOR (org + licensed-state scoping on
every read and write), not by prompting. The system prompt is a second,
defense-in-depth layer.

Streaming protocol (SSE):
  {"type": "meta", "states": [...]}            — once, at start
  {"type": "text", "text": "..."}              — assistant text deltas
  {"type": "tool", "name", "status", "summary"} — tool call start/finish
  {"type": "mutation"}                          — at least one write happened (frontend should refetch)
  {"type": "error", "message": "..."}
  [DONE]
"""
from __future__ import annotations
import json
from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.base import get_db
from app.core.auth import get_current_user, can_access_org_row
from app.models.user import User, UserRole
from app.models.patient import Patient
from app.models.visit import Visit

router = APIRouter(prefix="/chat", tags=["chat"])

MAX_ROUNDS = 8

_US_STATES = {
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA",
    "KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
    "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT",
    "VA","WA","WV","WI","WY","DC",
}


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatMessage] = []  # recent turns, max 10
    # Page context — set by the frontend when chatting from a visit or patient page
    visit_id: UUID | None = None
    patient_id: UUID | None = None


def _state_filter(user: User):
    """List of licensed states, or None for org-wide access. 403 if clinical user unconfigured."""
    states = [s.upper() for s in (user.licensed_states or []) if s.upper() in _US_STATES]
    if states:
        return states
    if user.role in (UserRole.admin, UserRole.super_admin, UserRole.billing):
        return None
    raise HTTPException(
        status_code=403,
        detail=(
            "Your account has no licensed states configured. "
            "Contact your administrator to set your licensed states before using the AI chat."
        ),
    )


async def _page_context(db: AsyncSession, user: User, body: ChatRequest) -> str:
    """If the clinician is on a visit or patient page, anchor the agent to it."""
    parts = []
    if body.visit_id:
        row = (await db.execute(
            select(Visit, Patient).join(Patient, Visit.patient_id == Patient.id).where(Visit.id == body.visit_id)
        )).first()
        if row and can_access_org_row(row[1].organization_id, user):
            v, p = row
            parts.append(
                f"The clinician currently has a visit open on screen:\n"
                f"  visit_id: {v.id}\n"
                f"  patient: {p.first_name} {p.last_name} (patient_id: {p.id}, MRN {p.mrn})\n"
                f"  type: {v.visit_type.value} | status: {v.status.value} | "
                f"scheduled: {v.scheduled_at.isoformat() if v.scheduled_at else 'unset'}\n"
                f"When asked to write or update 'the note' / 'this visit', use update_visit "
                f"with this visit_id. When asked about 'this patient', use this patient_id."
            )
    elif body.patient_id:
        p = (await db.execute(select(Patient).where(Patient.id == body.patient_id))).scalar_one_or_none()
        if p and can_access_org_row(p.organization_id, user):
            parts.append(
                f"The clinician currently has a patient chart open on screen: "
                f"{p.first_name} {p.last_name} (patient_id: {p.id}, MRN {p.mrn}). "
                f"'This patient' refers to them."
            )
    return "\n\n".join(parts)


def _build_system_prompt(user: User, states: list[str] | None, page_ctx: str) -> str:
    state_desc = ", ".join(states) if states else "all states (org-wide access)"
    ctx_block = f"\n\nCURRENT PAGE CONTEXT:\n{page_ctx}" if page_ctx else ""
    return f"""You are the ConcertoCare clinical AI assistant for {user.first_name} {user.last_name}, \
a {user.role.value.replace("_", " ")} with access scope: {state_desc}.

You have REAL tools that read and write the EMR. You can:
- Search patients and read full charts
- Find the best provider for a patient by GEOGRAPHY (find_providers_for_patient ranks \
licensed providers by distance to the patient's home and shows workload)
- Schedule, reschedule, reassign, and cancel visits (schedule_visit / update_visit)
- Write progress notes into visits: subjective, objective, assessment, plan, vitals (update_visit)
- Update any writable field on the patient chart (update_patient_chart)
- Create tasks and add diagnoses (auto HCC-mapped)

SCHEDULING ETIQUETTE — this is a conversation, not a one-shot command:
- When the request is ambiguous (no time, no provider preference), look up options first \
(find_providers_for_patient, get_schedule), then PRESENT 2-3 concrete options and ask which \
they want. Book only when the intent is clear.
- When the request is specific ("book Maria with the closest nurse Tuesday 10am"), check \
conflicts and book it directly, then confirm what you did.
- Always state exactly what you booked/changed: patient, provider, type, date/time.

CHART WRITES:
- Drafting note content (e.g. "write the assessment for this visit") — write it via \
update_visit and tell the clinician it's saved as a draft for their review.
- Never finalize a note (finalize=true) unless explicitly told to.
- For list fields (medications, allergies), read the chart first and write back the full \
merged list — never drop existing entries.

HIPAA MINIMUM NECESSARY — STRICTLY ENFORCED:
Every tool call is server-side filtered to your organization and licensed states ({state_desc}). \
If a tool returns an access error, tell the clinician plainly — do not retry or speculate. \
Never invent patient data; if a tool returns nothing, say so.

Today: {date.today().isoformat()}

Style: concise and actionable. Include patient name + MRN when discussing patients. Flag \
critical findings (HH/LL labs, O2 sat < 92%, weight gain > 2 lbs in HF patients) prominently.{ctx_block}"""


def _tool_summary(name: str, tool_input: dict, result: dict) -> str:
    """One-line human-readable description of a tool call for the UI."""
    if "error" in result:
        return f"{name}: {result['error']}"
    match name:
        case "search_patients":
            return f"Searched patients — {result.get('count', 0)} match(es)"
        case "get_patient_chart":
            return f"Read chart: {result.get('name', '?')} ({result.get('mrn', '?')})"
        case "update_patient_chart":
            return f"Updated chart fields: {', '.join(result.get('updated_fields', []))}"
        case "list_providers" | "find_providers_for_patient":
            return f"Found {len(result.get('providers', []))} provider(s)"
        case "get_schedule":
            return f"Checked schedule — {result.get('count', 0)} visit(s)"
        case "schedule_visit":
            return f"Scheduled {result.get('visit_type', 'visit')} for {result.get('patient', '?')} with {result.get('provider', '?')}"
        case "update_visit":
            return f"Updated visit ({', '.join(result.get('changed', []))}) for {result.get('patient', '?')}"
        case "create_task":
            return f"Created task: {result.get('title', '?')}"
        case "add_condition":
            return f"Added diagnosis {result.get('icd10', '?')}"
    return name


@router.post("")
async def chat(
    body: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Agentic AI chat. Returns a streaming Server-Sent Events response."""
    from app.modules.ai_engine.client import get_ai_client
    from app.modules.ai_engine.chat_tools import CHAT_TOOLS, WRITE_TOOLS, execute_chat_tool
    from app.core.config import get_settings

    settings = get_settings()
    if not settings.anthropic_api_key and settings.ai_provider == "anthropic":
        raise HTTPException(503, "AI service not configured (ANTHROPIC_API_KEY not set)")

    states = _state_filter(current_user)
    page_ctx = await _page_context(db, current_user, body)
    system_prompt = _build_system_prompt(current_user, states, page_ctx)

    messages: list[dict] = [{"role": m.role, "content": m.content} for m in body.history[-10:]]
    messages.append({"role": "user", "content": body.message})

    client = get_ai_client()

    async def generate():
        yield f"data: {json.dumps({'type': 'meta', 'states': states or []})}\n\n"
        wrote = False
        try:
            for _ in range(MAX_ROUNDS):
                async with client.messages.stream(
                    model=settings.ai_model,
                    max_tokens=2048,
                    system=system_prompt,
                    tools=CHAT_TOOLS,
                    messages=messages,
                ) as stream:
                    async for text in stream.text_stream:
                        yield f"data: {json.dumps({'type': 'text', 'text': text})}\n\n"
                    final = await stream.get_final_message()

                messages.append({"role": "assistant", "content": final.content})

                if final.stop_reason != "tool_use":
                    break

                tool_results = []
                for block in final.content:
                    if block.type != "tool_use":
                        continue
                    yield f"data: {json.dumps({'type': 'tool', 'name': block.name, 'status': 'running'})}\n\n"
                    result = await execute_chat_tool(block.name, block.input, db, current_user, states)
                    if block.name in WRITE_TOOLS and "error" not in result:
                        wrote = True
                    yield f"data: {json.dumps({'type': 'tool', 'name': block.name, 'status': 'done', 'summary': _tool_summary(block.name, block.input, result)})}\n\n"
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result, default=str),
                    })
                messages.append({"role": "user", "content": tool_results})

            if wrote:
                await db.commit()
                yield f"data: {json.dumps({'type': 'mutation'})}\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'type': 'error', 'message': str(exc)})}\n\n"

        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
