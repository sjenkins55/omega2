from pydantic import BaseModel, EmailStr
from datetime import date, datetime
from uuid import UUID
from app.models.patient import PatientStatus, InsuranceType


class DiagnosisItem(BaseModel):
    icd10_code: str | None = None
    description: str
    onset_date: date | None = None
    is_primary: bool = False
    is_active: bool = True


class MedicationItem(BaseModel):
    name: str
    rxnorm_code: str | None = None
    dose: str | None = None
    route: str | None = None
    frequency: str | None = None
    prescriber: str | None = None
    is_active: bool = True


class AllergyItem(BaseModel):
    allergen: str
    reaction: str | None = None
    severity: str | None = None


class CareTeamMember(BaseModel):
    name: str
    role: str
    npi: str | None = None
    phone: str | None = None
    organization: str | None = None


class PatientBase(BaseModel):
    first_name: str
    last_name: str
    date_of_birth: date
    gender: str | None = None
    phone: str | None = None
    email: str | None = None
    address: dict | None = None
    insurance_type: InsuranceType | None = None
    insurance_id: str | None = None
    primary_dx: str | None = None
    diagnoses: list[DiagnosisItem] | None = None
    medications: list[MedicationItem] | None = None
    allergies: list[AllergyItem] | None = None

    # Demographics
    preferred_name: str | None = None
    preferred_language: str | None = None
    preferred_contact_method: str | None = None
    emergency_contact: dict | None = None

    # Clinician assignment
    assigned_provider_id: UUID | None = None

    # Home care episode
    soc_date: date | None = None
    certification_from: date | None = None
    certification_through: date | None = None
    referral_source: str | None = None
    referring_physician_name: str | None = None
    referring_physician_npi: str | None = None
    discharge_date: date | None = None
    discharge_reason: str | None = None

    # Clinical context
    code_status: str | None = None
    living_situation: str | None = None
    caregiver_name: str | None = None
    caregiver_phone: str | None = None
    baseline_weight_lbs: float | None = None
    functional_limitations: dict | None = None
    advance_directives_on_file: bool = False

    # Insurance
    insurance_plan_name: str | None = None
    insurance_group_number: str | None = None
    secondary_insurance_type: InsuranceType | None = None
    secondary_insurance_id: str | None = None


class PatientCreate(PatientBase):
    mrn: str
    status: PatientStatus = PatientStatus.active


class PatientUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone: str | None = None
    email: str | None = None
    address: dict | None = None
    status: PatientStatus | None = None
    primary_dx: str | None = None
    diagnoses: list[DiagnosisItem] | None = None
    medications: list[MedicationItem] | None = None
    allergies: list[AllergyItem] | None = None
    care_team: list[CareTeamMember] | None = None

    preferred_name: str | None = None
    preferred_language: str | None = None
    preferred_contact_method: str | None = None
    emergency_contact: dict | None = None
    assigned_provider_id: UUID | None = None

    soc_date: date | None = None
    certification_from: date | None = None
    certification_through: date | None = None
    referral_source: str | None = None
    referring_physician_name: str | None = None
    referring_physician_npi: str | None = None
    discharge_date: date | None = None
    discharge_reason: str | None = None

    code_status: str | None = None
    living_situation: str | None = None
    caregiver_name: str | None = None
    caregiver_phone: str | None = None
    baseline_weight_lbs: float | None = None
    functional_limitations: dict | None = None
    advance_directives_on_file: bool | None = None

    insurance_plan_name: str | None = None
    insurance_group_number: str | None = None
    secondary_insurance_type: InsuranceType | None = None
    secondary_insurance_id: str | None = None


class PatientResponse(PatientBase):
    id: UUID
    mrn: str
    status: PatientStatus
    care_team: list[CareTeamMember] | None = None
    ai_risk_score: float | None = None
    ai_risk_factors: list | None = None
    ai_last_reviewed: datetime | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class PatientListResponse(BaseModel):
    patients: list[PatientResponse]
    total: int
