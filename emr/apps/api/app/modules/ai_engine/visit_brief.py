"""Generate AI pre-visit briefs and post-visit action items."""
from datetime import datetime
import json
from app.modules.ai_engine.client import get_ai_client
from app.core.config import get_settings

settings = get_settings()

SYSTEM_PROMPT = """You are a clinical AI assistant embedded in a home care EMR for an organization like ConcertoCare.
You analyze patient records to support skilled clinicians visiting patients at home.
Be concise, clinically precise, and always flag safety concerns clearly.
Never fabricate clinical data. If information is missing, say so explicitly."""


async def generate_pre_visit_brief(patient_data: dict, recent_visits: list[dict], recent_docs: list[dict]) -> dict:
    """
    Analyze patient context and return a structured pre-visit brief.
    Answers: what to focus on, what changed, what risks exist, what gaps to close.
    """
    client = get_ai_client()

    context = {
        "patient": patient_data,
        "recent_visits": recent_visits[-5:] if recent_visits else [],
        "recent_documents": recent_docs[-5:] if recent_docs else [],
    }

    prompt = f"""Review this home care patient's record and produce a pre-visit brief for today's clinician.

Patient context (JSON):
{json.dumps(context, indent=2, default=str)}

Return a JSON object with exactly these keys:
{{
  "priority_focus_areas": ["string"],
  "clinical_alerts": [{{"severity": "high|medium|low", "message": "string"}}],
  "medication_review_needed": bool,
  "medications_to_review": ["string"],
  "care_gaps": ["string"],
  "recent_changes": ["string"],
  "recommended_assessments": ["string"],
  "conversation_starters": ["string"],
  "risk_summary": "string",
  "visit_goals": ["string"]
}}

Return only valid JSON, no markdown fences."""

    response = await client.messages.create(
        model=settings.ai_model,
        max_tokens=2000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )

    try:
        return json.loads(response.content[0].text)
    except json.JSONDecodeError:
        # Attempt extraction if model added prose
        text = response.content[0].text
        start = text.find("{")
        end = text.rfind("}") + 1
        return json.loads(text[start:end])


async def process_visit_note(raw_note: str, patient_data: dict, visit_type: str) -> dict:
    """
    Transform a free-text or transcribed visit note into structured SOAP format
    and auto-generate action items + workflow triggers.
    """
    client = get_ai_client()

    prompt = f"""You are processing a {visit_type} home visit note.

Patient context:
{json.dumps(patient_data, indent=2, default=str)}

Clinician's raw note:
{raw_note}

Extract and return a JSON object with:
{{
  "subjective": "patient-reported symptoms, complaints, functional status",
  "objective": "measurable findings: vitals, exam, functional scores",
  "assessment": "clinical interpretation, diagnosis updates",
  "plan": "next steps, orders, referrals",
  "vital_signs": {{"bp": "", "hr": "", "rr": "", "temp": "", "o2_sat": "", "weight": "", "pain_score": ""}},
  "clinical_findings": {{}},
  "action_items": [
    {{"priority": "urgent|high|normal", "type": "order|referral|follow_up|alert|education", "description": "string", "due_in_hours": int}}
  ],
  "workflow_triggers": [
    {{"trigger_type": "string", "reason": "string", "payload": {{}}}}
  ],
  "coding_suggestions": [{{"code": "ICD-10 code", "description": "string"}}],
  "quality_measures": ["string"],
  "note_summary": "2-3 sentence visit summary"
}}

Return only valid JSON."""

    response = await client.messages.create(
        model=settings.ai_model,
        max_tokens=3000,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )

    try:
        return json.loads(response.content[0].text)
    except json.JSONDecodeError:
        text = response.content[0].text
        start = text.find("{")
        end = text.rfind("}") + 1
        return json.loads(text[start:end])


async def compute_risk_score(patient_data: dict, visit_history: list[dict]) -> dict:
    """Compute an AI risk stratification score and contributing factors."""
    client = get_ai_client()

    prompt = f"""Compute a risk stratification score for this home care patient.

Patient data:
{json.dumps(patient_data, indent=2, default=str)}

Visit history (last 10):
{json.dumps(visit_history[-10:], indent=2, default=str)}

Return JSON:
{{
  "risk_score": 0.0-1.0,
  "risk_tier": "low|medium|high|critical",
  "risk_factors": [{{"factor": "string", "weight": 0.0-1.0, "description": "string"}}],
  "protective_factors": ["string"],
  "hospitalization_risk_90d": 0.0-1.0,
  "ed_visit_risk_30d": 0.0-1.0,
  "recommended_visit_frequency": "string",
  "rationale": "string"
}}

Return only valid JSON."""

    response = await client.messages.create(
        model=settings.ai_model_opus,
        max_tokens=1500,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )

    try:
        return json.loads(response.content[0].text)
    except json.JSONDecodeError:
        text = response.content[0].text
        start = text.find("{")
        end = text.rfind("}") + 1
        return json.loads(text[start:end])
