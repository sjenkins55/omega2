from pydantic import BaseModel, EmailStr
from datetime import date, datetime
from uuid import UUID
from typing import Any
from app.models.patient import PatientStatus, InsuranceType


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
    diagnoses: list | None = None
    medications: list | None = None
    allergies: list | None = None


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
    diagnoses: list | None = None
    medications: list | None = None
    allergies: list | None = None
    care_team: list | None = None


class PatientResponse(PatientBase):
    id: UUID
    mrn: str
    status: PatientStatus
    ai_risk_score: float | None = None
    ai_risk_factors: list | None = None
    ai_last_reviewed: datetime | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class PatientListResponse(BaseModel):
    patients: list[PatientResponse]
    total: int
