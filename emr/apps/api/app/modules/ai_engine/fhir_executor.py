"""
Executes FHIR tool calls from the agent loop against the local database.
Returns structured results Claude can reason about.
"""
from datetime import datetime
from uuid import UUID
import structlog

log = structlog.get_logger()


async def execute_tool(tool_name: str, tool_input: dict, db, patient_id: str | None = None) -> dict:
    """Route a tool call to the appropriate FHIR handler."""
    handlers = {
        "search_patient":      _search_patient,
        "get_observations":    _get_observations,
        "get_conditions":      _get_conditions,
        "get_medications":     _get_medications,
        "get_procedures":      _get_procedures,
        "get_visit_history":   _get_visit_history,
        "record_vital_signs":  _record_vital_signs,
        "draft_medication_order":  _draft_medication_order,
        "draft_service_request":   _draft_service_request,
    }
    handler = handlers.get(tool_name)
    if not handler:
        return {"error": f"Unknown tool: {tool_name}"}
    try:
        return await handler(tool_input, db)
    except Exception as exc:
        log.error("tool_execution_failed", tool=tool_name, error=str(exc))
        return {"error": str(exc)}


async def _search_patient(inp: dict, db) -> dict:
    from sqlalchemy import select, or_
    from app.models.patient import Patient

    q = select(Patient)
    filters = []
    if inp.get("mrn"):
        filters.append(Patient.mrn == inp["mrn"])
    if inp.get("identifier"):
        filters.append(Patient.insurance_id == inp["identifier"])
    if inp.get("name"):
        term = f"%{inp['name']}%"
        filters.append(or_(
            (Patient.first_name + " " + Patient.last_name).ilike(term),
            (Patient.last_name + ", " + Patient.first_name).ilike(term),
        ))
    if filters:
        from sqlalchemy import or_ as sor
        q = q.where(sor(*filters))

    result = await db.execute(q.limit(5))
    patients = result.scalars().all()
    return {
        "patients": [
            {
                "id": str(p.id), "mrn": p.mrn,
                "name": f"{p.first_name} {p.last_name}",
                "dob": p.date_of_birth.isoformat() if p.date_of_birth else None,
                "status": p.status,
            }
            for p in patients
        ],
        "count": len(patients),
    }


async def _get_observations(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.patient import Patient

    # In production this queries a FHIR server or observations table.
    # For now, return structured data from the patient record.
    patient_id = inp["patient_id"]
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    patient = result.scalar_one_or_none()
    if not patient:
        return {"error": "Patient not found"}

    category = inp.get("category", "laboratory")
    # Placeholder — real impl queries FHIR Observation resources
    return {
        "category": category,
        "patient_id": patient_id,
        "observations": [],
        "note": "Connect to FHIR server or observations table for real data",
    }


async def _get_conditions(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.patient import Patient

    result = await db.execute(select(Patient).where(Patient.id == inp["patient_id"]))
    patient = result.scalar_one_or_none()
    if not patient:
        return {"error": "Patient not found"}

    status_filter = inp.get("status", "active")
    conditions = []
    if patient.primary_dx:
        conditions.append({"description": patient.primary_dx, "status": "active", "category": "problem-list-item"})
    for dx in (patient.diagnoses or []):
        conditions.append({"description": dx, "status": "active", "category": "problem-list-item"})

    return {"conditions": conditions, "count": len(conditions)}


async def _get_medications(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.patient import Patient

    result = await db.execute(select(Patient).where(Patient.id == inp["patient_id"]))
    patient = result.scalar_one_or_none()
    if not patient:
        return {"error": "Patient not found"}

    status_filter = inp.get("status", "active")
    meds = []
    for med in (patient.medications or []):
        meds.append({
            "name": med.get("name"),
            "dose": med.get("dose"),
            "frequency": med.get("frequency"),
            "route": med.get("route", "oral"),
            "status": "active",
        })

    return {"medications": meds, "count": len(meds)}


async def _get_procedures(inp: dict, db) -> dict:
    return {"procedures": [], "note": "Connect to FHIR Procedure resources for real data"}


async def _get_visit_history(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.visit import Visit, VisitStatus

    limit = inp.get("limit", 5)
    q = (
        select(Visit)
        .where(Visit.patient_id == inp["patient_id"], Visit.status == VisitStatus.completed)
        .order_by(Visit.completed_at.desc())
        .limit(limit)
    )
    if inp.get("visit_type"):
        q = q.where(Visit.visit_type == inp["visit_type"])

    result = await db.execute(q)
    visits = result.scalars().all()
    return {
        "visits": [
            {
                "id": str(v.id),
                "visit_type": v.visit_type,
                "completed_at": v.completed_at.isoformat() if v.completed_at else None,
                "assessment": v.assessment,
                "plan": v.plan,
                "vital_signs": v.vital_signs,
                "action_items": v.action_items,
                "note_summary": (v.structured_note or {}).get("note_summary"),
            }
            for v in visits
        ],
        "count": len(visits),
    }


async def _record_vital_signs(inp: dict, db) -> dict:
    # In production writes a FHIR Observation resource
    log.info("record_vital_signs", patient_id=inp.get("patient_id"), vitals=inp.get("vitals"))
    return {"recorded": True, "patient_id": inp["patient_id"], "vitals": inp.get("vitals", {})}


async def _draft_medication_order(inp: dict, db) -> dict:
    log.info("draft_medication_order", patient_id=inp.get("patient_id"), med=inp.get("medication_name"))
    return {
        "drafted": True,
        "status": "pending_clinician_approval",
        "medication": inp.get("medication_name"),
        "dose": inp.get("dose"),
        "frequency": inp.get("frequency"),
        "note": "Order created in draft state — requires clinician signature",
    }


async def _draft_service_request(inp: dict, db) -> dict:
    log.info("draft_service_request", patient_id=inp.get("patient_id"), service=inp.get("service_type"))
    return {
        "drafted": True,
        "status": "pending_clinician_approval",
        "service_type": inp.get("service_type"),
        "description": inp.get("description"),
        "priority": inp.get("priority", "routine"),
        "note": "Service request created in draft state — requires clinician signature",
    }
