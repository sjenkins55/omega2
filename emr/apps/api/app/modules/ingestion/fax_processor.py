"""Fax and document ingestion pipeline."""
import json
import re
from app.modules.ai_engine.client import get_ai_client
from app.core.config import get_settings

settings = get_settings()

SYSTEM_PROMPT = """You are a medical document processing AI for a home care EMR.
Extract and classify clinical information from documents accurately.
Never fabricate data. Flag ambiguous or low-confidence extractions."""


async def classify_and_extract_document(raw_text: str, file_name: str) -> dict:
    """
    Classify a document and extract structured clinical data.
    Handles labs, discharge summaries, referrals, orders, insurance docs.
    """
    client = get_ai_client()

    prompt = f"""Analyze this medical document and extract structured data.

Filename: {file_name}

Document text:
{raw_text[:8000]}

Return JSON with:
{{
  "document_type": "lab_result|discharge_summary|referral|order|insurance|consent|care_plan|fax|other",
  "confidence": 0.0-1.0,
  "patient_identifiers": {{
    "name": "",
    "date_of_birth": "",
    "mrn": "",
    "insurance_id": ""
  }},
  "sender": {{
    "name": "",
    "organization": "",
    "fax_number": "",
    "phone": "",
    "npi": ""
  }},
  "date_of_service": "",
  "clinical_summary": "string",
  "extracted_data": {{}},
  "diagnoses": [{{"code": "", "description": ""}}],
  "medications": [{{"name": "", "dose": "", "frequency": "", "route": ""}}],
  "lab_values": [{{"test": "", "value": "", "unit": "", "reference_range": "", "flag": "normal|high|low|critical"}}],
  "requires_action": true|false,
  "action_description": "string",
  "urgency": "routine|urgent|stat",
  "suggested_workflow_triggers": ["string"],
  "key_findings": ["string"]
}}

Return only valid JSON."""

    response = await client.messages.create(
        model=settings.ai_model,
        max_tokens=2000,
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


async def match_patient_from_document(extracted_data: dict, db_session) -> str | None:
    """
    Attempt to match a document to an existing patient using extracted identifiers.
    Returns patient_id if found, None if needs manual review.
    """
    from sqlalchemy import select
    from app.models.patient import Patient

    identifiers = extracted_data.get("patient_identifiers", {})
    mrn = identifiers.get("mrn", "").strip()
    insurance_id = identifiers.get("insurance_id", "").strip()
    name = identifiers.get("name", "").strip()
    dob = identifiers.get("date_of_birth", "").strip()

    if mrn:
        result = await db_session.execute(select(Patient).where(Patient.mrn == mrn))
        patient = result.scalar_one_or_none()
        if patient:
            return str(patient.id)

    if insurance_id:
        result = await db_session.execute(select(Patient).where(Patient.insurance_id == insurance_id))
        patient = result.scalar_one_or_none()
        if patient:
            return str(patient.id)

    # Fuzzy name + DOB match
    if name and dob:
        parts = name.split()
        if len(parts) >= 2:
            last = parts[-1]
            first = parts[0]
            result = await db_session.execute(
                select(Patient).where(
                    Patient.last_name.ilike(f"%{last}%"),
                    Patient.first_name.ilike(f"%{first}%"),
                )
            )
            patients = result.scalars().all()
            if len(patients) == 1:
                return str(patients[0].id)

    return None
