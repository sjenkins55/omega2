"""
Visit AI functions — upgraded to use the tool-use agent loop.
Claude now iteratively queries FHIR tools instead of receiving a one-shot data dump.
"""
import json
from app.modules.ai_engine.agent_loop import run_agent
from app.core.config import get_settings

settings = get_settings()


async def generate_pre_visit_brief(patient_id: str, visit_id: str, db) -> dict:
    """
    Generate a pre-visit brief by letting Claude query the patient's record
    iteratively via FHIR tools, then produce a structured brief.
    """
    task = f"""\
You are preparing a pre-visit brief for patient ID {patient_id} (visit ID {visit_id}).

Use your FHIR tools to retrieve:
1. The patient's active conditions and problem list
2. Current medications
3. Recent lab results and vital signs (last 30 days)
4. The last 3-5 visit notes

Then produce a structured pre-visit brief as a JSON object with exactly these keys:
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

Return ONLY the JSON object, no prose."""

    output = await run_agent(task, patient_id, db, model=settings.ai_model)
    raw = output["result"]

    try:
        brief = json.loads(raw)
    except json.JSONDecodeError:
        start, end = raw.find("{"), raw.rfind("}") + 1
        brief = json.loads(raw[start:end]) if start != -1 else {"error": "Failed to parse brief", "raw": raw}

    brief["_meta"] = {"rounds": output["rounds"], "tool_calls": len(output["tool_calls"]), "model": output["model"]}
    return brief


async def process_visit_note(raw_note: str, patient_id: str, visit_type: str, db) -> dict:
    """
    Process a raw/dictated visit note using the agent loop.
    Claude can query prior visits and current meds to fill in context
    before structuring the SOAP note and generating action items.
    """
    task = f"""\
You are structuring a {visit_type} home visit note for patient ID {patient_id}.

First, use your tools to retrieve:
- Current medications (to cross-reference the clinician's note)
- Active conditions (to inform the assessment)
- Last 2 visit notes (to identify changes)

Then process this raw clinician note:

---
{raw_note}
---

Return a JSON object with:
{{
  "subjective": "patient-reported symptoms and history",
  "objective": "measurable exam findings",
  "assessment": "clinical interpretation",
  "plan": "next steps",
  "vital_signs": {{"bp": "", "hr": "", "rr": "", "temp": "", "o2_sat": "", "weight": "", "pain_score": ""}},
  "clinical_findings": {{}},
  "action_items": [
    {{"priority": "urgent|high|normal", "type": "order|referral|follow_up|alert|education", "description": "string", "due_in_hours": int}}
  ],
  "workflow_triggers": [
    {{"trigger_type": "string", "reason": "string", "payload": {{}}}}
  ],
  "coding_suggestions": [{{"code": "ICD-10", "description": "string"}}],
  "quality_measures": ["string"],
  "note_summary": "2-3 sentence visit summary"
}}

Return ONLY the JSON object."""

    output = await run_agent(task, patient_id, db, model=settings.ai_model)
    raw = output["result"]

    try:
        structured = json.loads(raw)
    except json.JSONDecodeError:
        start, end = raw.find("{"), raw.rfind("}") + 1
        structured = json.loads(raw[start:end]) if start != -1 else {"error": "Parse failed", "raw": raw}

    structured["_meta"] = {"rounds": output["rounds"], "tool_calls": len(output["tool_calls"])}
    return structured


async def compute_risk_score(patient_id: str, db) -> dict:
    """
    Compute AI risk stratification using Opus for deeper reasoning.
    Claude queries full patient history before scoring.
    """
    task = f"""\
Compute a comprehensive risk stratification score for patient ID {patient_id}.

Use your tools to retrieve:
- Active conditions and problem list
- All current medications
- Recent lab results (last 90 days)
- Recent vital signs (last 30 days)
- Last 5-10 visit notes

Then return a JSON risk assessment:
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

Return ONLY the JSON object."""

    output = await run_agent(task, patient_id, db, model=settings.ai_model_opus, max_rounds=10)
    raw = output["result"]

    try:
        score = json.loads(raw)
    except json.JSONDecodeError:
        start, end = raw.find("{"), raw.rfind("}") + 1
        score = json.loads(raw[start:end]) if start != -1 else {"error": "Parse failed", "raw": raw}

    score["_meta"] = {"rounds": output["rounds"], "tool_calls": len(output["tool_calls"]), "model": output["model"]}
    return score
