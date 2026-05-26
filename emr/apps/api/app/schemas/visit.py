from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from app.models.visit import VisitStatus, VisitType


class VisitCreate(BaseModel):
    patient_id: UUID
    visit_type: VisitType
    scheduled_at: datetime | None = None
    clinician_id: UUID | None = None


class VisitUpdate(BaseModel):
    status: VisitStatus | None = None
    scheduled_at: datetime | None = None
    clinician_id: UUID | None = None
    vital_signs: dict | None = None
    raw_note: str | None = None


class VisitResponse(BaseModel):
    id: UUID
    patient_id: UUID
    clinician_id: UUID | None
    visit_type: VisitType
    status: VisitStatus
    scheduled_at: datetime | None
    started_at: datetime | None
    completed_at: datetime | None
    subjective: str | None
    objective: str | None
    assessment: str | None
    plan: str | None
    vital_signs: dict | None
    action_items: list | None
    note_finalized: bool
    ai_processing_status: str
    pre_visit_brief: dict | None
    created_at: datetime

    class Config:
        from_attributes = True


class NoteSubmission(BaseModel):
    raw_note: str
    finalize: bool = False
