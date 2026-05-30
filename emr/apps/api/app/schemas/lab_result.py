from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class LabResultBase(BaseModel):
    source: str
    loinc_code: str | None = None
    display_name: str
    category: str | None = None
    value_quantity: float | None = None
    value_string: str | None = None
    unit: str | None = None
    reference_range_low: float | None = None
    reference_range_high: float | None = None
    interpretation: str | None = None
    status: str = "final"
    collected_at: datetime | None = None
    resulted_at: datetime | None = None
    ordering_provider: str | None = None
    performing_lab: str | None = None
    visit_id: UUID | None = None
    external_id: str | None = None
    raw_fhir: dict | None = None


class LabResultCreate(LabResultBase):
    pass


class LabResultResponse(LabResultBase):
    id: UUID
    patient_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
