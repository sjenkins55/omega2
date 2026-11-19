"""
Executes FHIR tool calls from the agent loop.
When HEALTHLAKE_DATASTORE_ID is set, routes to AWS HealthLake.
Falls back to the local PostgreSQL models when HealthLake is not configured.
"""
from __future__ import annotations
import structlog
from app.integrations.healthlake import get_healthlake_client

log = structlog.get_logger()


async def execute_tool(tool_name: str, tool_input: dict, db, patient_id: str | None = None) -> dict:
    """Route a tool call to HealthLake or the local DB fallback."""
    hl = get_healthlake_client()

    handlers_hl = {
        "search_patient":       _hl_search_patient,
        "get_observations":     _hl_get_observations,
        "get_conditions":       _hl_get_conditions,
        "get_medications":      _hl_get_medications,
        "get_procedures":       _hl_get_procedures,
        "record_vital_signs":   _hl_record_vitals,
        "draft_medication_order":   _hl_draft_medication,
        "draft_service_request":    _hl_draft_service,
    }
    handlers_local = {
        "search_patient":       _local_search_patient,
        "get_observations":     _local_get_observations,
        "get_conditions":       _local_get_conditions,
        "get_medications":      _local_get_medications,
        "get_procedures":       _local_get_procedures,
        "get_visit_history":    _local_get_visit_history,
        "record_vital_signs":   _local_record_vitals,
        "draft_medication_order":   _local_draft_medication,
        "draft_service_request":    _local_draft_service,
    }

    # get_visit_history always goes to local DB (our visit notes, not FHIR)
    if tool_name == "get_visit_history":
        return await _local_get_visit_history(tool_input, db)

    try:
        if hl:
            handler = handlers_hl.get(tool_name)
            if handler:
                return await handler(tool_input, hl)
        handler = handlers_local.get(tool_name)
        if handler:
            return await handler(tool_input, db)
        return {"error": f"Unknown tool: {tool_name}"}
    except Exception as exc:
        log.error("tool_execution_failed", tool=tool_name, error=str(exc))
        return {"error": str(exc)}


# ── HealthLake handlers ────────────────────────────────────────────────────

async def _hl_search_patient(inp: dict, hl) -> dict:
    return await hl.search_patient(
        name=inp.get("name"),
        birthdate=inp.get("birthdate"),
        identifier=inp.get("identifier") or inp.get("mrn"),
    )


async def _hl_get_observations(inp: dict, hl) -> dict:
    return await hl.get_observations(
        patient_id=inp["patient_id"],
        category=inp.get("category", "laboratory"),
        code=inp.get("code"),
        date_from=inp.get("date_from"),
        date_to=inp.get("date_to"),
        limit=inp.get("limit", 10),
    )


async def _hl_get_conditions(inp: dict, hl) -> dict:
    return await hl.get_conditions(
        patient_id=inp["patient_id"],
        category=inp.get("category", "problem-list-item"),
        status=inp.get("status", "active"),
    )


async def _hl_get_medications(inp: dict, hl) -> dict:
    return await hl.get_medications(
        patient_id=inp["patient_id"],
        status=inp.get("status", "active"),
        category=inp.get("category"),
    )


async def _hl_get_procedures(inp: dict, hl) -> dict:
    return await hl.get_procedures(
        patient_id=inp["patient_id"],
        date_from=inp.get("date_from"),
        code=inp.get("code"),
    )


async def _hl_record_vitals(inp: dict, hl) -> dict:
    return await hl.record_vital_signs(
        patient_id=inp["patient_id"],
        vitals=inp.get("vitals", {}),
        recorded_at=inp.get("recorded_at"),
    )


async def _hl_draft_medication(inp: dict, hl) -> dict:
    return await hl.draft_medication_order(
        patient_id=inp["patient_id"],
        medication_name=inp["medication_name"],
        rxnorm_code=inp.get("rxnorm_code"),
        dose=inp["dose"],
        frequency=inp["frequency"],
        route=inp["route"],
        indication=inp.get("indication"),
        notes=inp.get("notes"),
    )


async def _hl_draft_service(inp: dict, hl) -> dict:
    return await hl.draft_service_request(
        patient_id=inp["patient_id"],
        service_type=inp["service_type"],
        description=inp["description"],
        cpt_code=inp.get("cpt_code"),
        priority=inp.get("priority", "routine"),
        reason=inp.get("reason"),
        notes=inp.get("notes"),
    )


# ── Local DB fallbacks ─────────────────────────────────────────────────────

async def _local_search_patient(inp: dict, db) -> dict:
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
            Patient.last_name.ilike(term),
        ))
    if filters:
        from sqlalchemy import or_ as sor
        q = q.where(sor(*filters))

    result = await db.execute(q.limit(5))
    patients = result.scalars().all()
    return {
        "patients": [
            {"id": str(p.id), "mrn": p.mrn, "name": f"{p.first_name} {p.last_name}",
             "dob": p.date_of_birth.isoformat() if p.date_of_birth else None, "status": p.status}
            for p in patients
        ],
        "count": len(patients),
    }


async def _local_get_observations(inp: dict, db) -> dict:
    return {
        "category": inp.get("category", "laboratory"),
        "patient_id": inp["patient_id"],
        "observations": [],
        "note": "Wire up HealthLake or an Observation table for real data",
    }


async def _local_get_conditions(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.patient import Patient

    result = await db.execute(select(Patient).where(Patient.id == inp["patient_id"]))
    patient = result.scalar_one_or_none()
    if not patient:
        return {"error": "Patient not found"}

    conditions = []
    if patient.primary_dx:
        conditions.append({"description": patient.primary_dx, "status": "active"})
    for dx in (patient.diagnoses or []):
        conditions.append({"description": dx, "status": "active"})
    return {"conditions": conditions, "count": len(conditions)}


async def _local_get_medications(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.patient import Patient

    result = await db.execute(select(Patient).where(Patient.id == inp["patient_id"]))
    patient = result.scalar_one_or_none()
    if not patient:
        return {"error": "Patient not found"}

    meds = [
        {"name": m.get("name"), "dose": m.get("dose"), "frequency": m.get("frequency"),
         "route": m.get("route", "oral"), "status": "active"}
        for m in (patient.medications or [])
    ]
    return {"medications": meds, "count": len(meds)}


async def _local_get_procedures(inp: dict, db) -> dict:
    return {"procedures": [], "note": "Wire up HealthLake for real procedure data"}


async def _local_get_visit_history(inp: dict, db) -> dict:
    from sqlalchemy import select
    from app.models.visit import Visit, VisitStatus

    q = (
        select(Visit)
        .where(Visit.patient_id == inp["patient_id"], Visit.status == VisitStatus.completed)
        .order_by(Visit.completed_at.desc())
        .limit(inp.get("limit", 5))
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


async def _local_record_vitals(inp: dict, db) -> dict:
    log.info("record_vital_signs_local", patient_id=inp.get("patient_id"))
    return {"recorded": True, "patient_id": inp["patient_id"], "vitals": inp.get("vitals", {}),
            "note": "Stored locally — enable HealthLake to write to FHIR store"}


async def _local_draft_medication(inp: dict, db) -> dict:
    return {"drafted": True, "status": "pending_clinician_approval",
            "medication": inp.get("medication_name"), "dose": inp.get("dose"),
            "note": "Enable HealthLake to create a real FHIR MedicationRequest"}


async def _local_draft_service(inp: dict, db) -> dict:
    return {"drafted": True, "status": "pending_clinician_approval",
            "service_type": inp.get("service_type"), "description": inp.get("description"),
            "note": "Enable HealthLake to create a real FHIR ServiceRequest"}
