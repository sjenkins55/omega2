from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from typing import Any
from pydantic import BaseModel
from app.db.base import get_db
from app.models.visit import Visit, VisitStatus
from app.models.patient import Patient
from app.schemas.visit import VisitCreate, VisitUpdate, VisitResponse, NoteSubmission

router = APIRouter(prefix="/visits", tags=["visits"])


@router.get("", response_model=list[VisitResponse])
async def list_visits(
    patient_id: UUID | None = None,
    status: VisitStatus | None = None,
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = select(Visit)
    if patient_id:
        query = query.where(Visit.patient_id == patient_id)
    if status:
        query = query.where(Visit.status == status)
    query = query.order_by(Visit.scheduled_at.desc().nullslast()).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{visit_id}", response_model=VisitResponse)
async def get_visit(visit_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")
    return visit


@router.post("", response_model=VisitResponse, status_code=201)
async def create_visit(body: VisitCreate, db: AsyncSession = Depends(get_db)):
    visit = Visit(**body.model_dump())
    db.add(visit)
    await db.flush()
    await db.refresh(visit)
    return visit


@router.get("/{visit_id}/pre-brief")
async def get_pre_visit_brief(visit_id: UUID, db: AsyncSession = Depends(get_db)):
    """
    Returns the AI-generated pre-visit brief for a scheduled visit.
    Generates on demand and caches on the visit record.
    """
    from app.modules.ai_engine.visit_brief import generate_pre_visit_brief

    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")

    if visit.pre_visit_brief:
        return visit.pre_visit_brief

    brief = await generate_pre_visit_brief(str(visit.patient_id), str(visit_id), db)

    visit.pre_visit_brief = brief
    await db.flush()
    return brief


@router.post("/{visit_id}/start")
async def start_visit(visit_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")
    visit.status = VisitStatus.in_progress
    visit.started_at = datetime.utcnow()
    await db.flush()
    return {"status": "started", "visit_id": str(visit_id)}


@router.post("/{visit_id}/submit-note")
async def submit_note(visit_id: UUID, body: NoteSubmission, db: AsyncSession = Depends(get_db)):
    """
    Accept a free-text or transcribed note, run AI processing,
    auto-generate SOAP note + action items + workflow triggers.
    """
    from app.modules.ai_engine.visit_brief import process_visit_note
    from app.modules.workflows.engine import workflow_engine

    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")

    visit.raw_note = body.raw_note
    visit.ai_processing_status = "processing"
    await db.flush()

    structured = await process_visit_note(body.raw_note, str(visit.patient_id), visit.visit_type, db)

    visit.structured_note = structured
    visit.subjective = structured.get("subjective")
    visit.objective = structured.get("objective")
    visit.assessment = structured.get("assessment")
    visit.plan = structured.get("plan")
    visit.vital_signs = structured.get("vital_signs")
    visit.clinical_findings = structured.get("clinical_findings")
    visit.action_items = structured.get("action_items", [])
    visit.ai_processing_status = "completed"

    if body.finalize:
        visit.status = VisitStatus.completed
        visit.completed_at = datetime.utcnow()
        visit.note_finalized = True

        triggers = structured.get("workflow_triggers", [])
        run_ids = []
        for trig in triggers:
            payload = {
                "patient_id": str(visit.patient_id),
                "visit_id": str(visit_id),
                "clinician_id": str(visit.clinician_id) if visit.clinician_id else None,
                **trig.get("payload", {}),
            }
            ids = await workflow_engine.trigger(trig["trigger_type"], payload, db)
            run_ids.extend(ids)

        visit.triggered_workflows = run_ids

        # Also fire visit_completed trigger
        await workflow_engine.trigger("visit_completed", {
            "patient_id": str(visit.patient_id),
            "visit_id": str(visit_id),
            "visit_type": visit.visit_type,
        }, db)

    await db.flush()
    return {"structured_note": structured, "action_items": visit.action_items}


class DirectNoteWrite(BaseModel):
    """Write structured note fields directly — for API integrations and external tools."""
    raw_note: str | None = None
    subjective: str | None = None
    objective: str | None = None
    assessment: str | None = None
    plan: str | None = None
    vital_signs: dict[str, Any] | None = None
    clinical_findings: dict[str, Any] | None = None
    action_items: list[dict[str, Any]] | None = None
    structured_note: dict[str, Any] | None = None
    finalize: bool = False


@router.post("/{visit_id}/notes")
async def write_note_directly(
    visit_id: UUID,
    body: DirectNoteWrite,
    db: AsyncSession = Depends(get_db),
):
    """
    Write note content directly into a visit without AI processing.
    Accepts any combination of raw_note, SOAP fields, vitals, action items.
    Use finalize=true to mark the visit completed and trigger workflows.
    Intended for integrations: mobile apps, external EHR imports, dictation services.
    """
    from app.modules.workflows.engine import workflow_engine

    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")

    if body.raw_note is not None:
        visit.raw_note = body.raw_note
    if body.subjective is not None:
        visit.subjective = body.subjective
    if body.objective is not None:
        visit.objective = body.objective
    if body.assessment is not None:
        visit.assessment = body.assessment
    if body.plan is not None:
        visit.plan = body.plan
    if body.vital_signs is not None:
        visit.vital_signs = body.vital_signs
    if body.clinical_findings is not None:
        visit.clinical_findings = body.clinical_findings
    if body.action_items is not None:
        visit.action_items = body.action_items
    if body.structured_note is not None:
        visit.structured_note = body.structured_note

    # Merge SOAP fields into structured_note for consistency
    if any([body.subjective, body.objective, body.assessment, body.plan]):
        existing = visit.structured_note or {}
        if body.subjective:
            existing["subjective"] = body.subjective
        if body.objective:
            existing["objective"] = body.objective
        if body.assessment:
            existing["assessment"] = body.assessment
        if body.plan:
            existing["plan"] = body.plan
        visit.structured_note = existing

    visit.ai_processing_status = "completed"

    if body.finalize:
        visit.status = VisitStatus.completed
        visit.completed_at = datetime.utcnow()
        visit.note_finalized = True
        await workflow_engine.trigger("visit_completed", {
            "patient_id": str(visit.patient_id),
            "visit_id": str(visit_id),
            "visit_type": visit.visit_type,
        }, db)

    await db.commit()
    return {
        "visit_id": str(visit_id),
        "status": visit.status,
        "note_finalized": visit.note_finalized,
        "fields_written": [
            f for f in ["raw_note", "subjective", "objective", "assessment", "plan",
                        "vital_signs", "clinical_findings", "action_items", "structured_note"]
            if getattr(body, f) is not None
        ],
    }


@router.patch("/{visit_id}", response_model=VisitResponse)
async def update_visit(visit_id: UUID, body: VisitUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(visit, field, value)
    await db.flush()
    await db.refresh(visit)
    return visit
