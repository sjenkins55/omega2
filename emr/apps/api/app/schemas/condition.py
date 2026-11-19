from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class ConditionBase(BaseModel):
    icd10_code: str | None = None
    icd10_description: str
    hcc_code: str | None = None
    hcc_description: str | None = None
    clinical_status: str = "active"
    verification_status: str = "provisional"
    is_primary: bool = False
    source: str
    onset_date: date | None = None
    abatement_date: date | None = None
    recorded_date: date
    asserter_name: str | None = None
    asserter_npi: str | None = None
    visit_id: UUID | None = None
    document_id: UUID | None = None
    external_id: str | None = None
    raw_fhir: dict | None = None


class ConditionCreate(ConditionBase):
    pass


class ConditionConfirm(BaseModel):
    """Payload for a provider confirming a provisional condition."""
    verification_status: str = "confirmed"
    recaptured_in_year: int | None = None
    recaptured_visit_id: UUID | None = None
    asserter_name: str | None = None
    asserter_npi: str | None = None


class ConditionResponse(ConditionBase):
    id: UUID
    patient_id: UUID
    recaptured_in_year: int | None = None
    recaptured_visit_id: UUID | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
