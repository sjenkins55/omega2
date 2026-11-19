"""
FHIR R4 read-only API — 21st Century Cures / USCDI compliance.
Surfaces existing data as standard FHIR resources.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from app.db.base import get_db
from app.core.auth import get_current_user, get_scoped_patient
from app.models.patient import Patient
from app.models.condition import Condition
from app.models.lab_result import LabResult

router = APIRouter(prefix="/fhir/r4", tags=["fhir"])

FHIR_BASE = "http://concertocare.io/fhir/r4"


def patient_to_fhir(p: Patient) -> dict:
    resource = {
        "resourceType": "Patient",
        "id": str(p.id),
        "identifier": [{"system": "http://concertocare.io/mrn", "value": p.mrn}],
        "name": [{"family": p.last_name, "given": [p.first_name]}],
        "birthDate": p.date_of_birth.isoformat() if p.date_of_birth else None,
        "gender": (p.gender or "unknown").lower(),
        "telecom": [],
    }
    if p.phone:
        resource["telecom"].append({"system": "phone", "value": p.phone})
    if p.email:
        resource["telecom"].append({"system": "email", "value": p.email})
    if p.address:
        resource["address"] = [p.address]
    return resource


def condition_to_fhir(c: Condition) -> dict:
    coding = []
    if c.icd10_code:
        coding.append({"system": "http://hl7.org/fhir/sid/icd-10-cm", "code": c.icd10_code, "display": c.icd10_description})
    return {
        "resourceType": "Condition",
        "id": str(c.id),
        "subject": {"reference": f"Patient/{c.patient_id}"},
        "code": {"coding": coding, "text": c.icd10_description},
        "clinicalStatus": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": c.clinical_status}]},
        "verificationStatus": {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/condition-ver-status", "code": c.verification_status}]},
        "onsetDateTime": c.onset_date.isoformat() if c.onset_date else None,
        "recordedDate": c.recorded_date.isoformat() if c.recorded_date else None,
    }


def lab_to_fhir(l: LabResult) -> dict:
    coding = []
    if l.loinc_code:
        coding.append({"system": "http://loinc.org", "code": l.loinc_code, "display": l.display_name})
    resource = {
        "resourceType": "Observation",
        "id": str(l.id),
        "status": l.status,
        "subject": {"reference": f"Patient/{l.patient_id}"},
        "code": {"coding": coding, "text": l.display_name},
        "effectiveDateTime": l.collected_at.isoformat() if l.collected_at else None,
    }
    if l.value_quantity is not None:
        resource["valueQuantity"] = {"value": l.value_quantity, "unit": l.unit, "system": "http://unitsofmeasure.org"}
    elif l.value_string:
        resource["valueString"] = l.value_string
    if l.interpretation:
        resource["interpretation"] = [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation", "code": l.interpretation}]}]
    return resource


@router.get("/Patient/{patient_id}")
async def fhir_get_patient(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    p = await get_scoped_patient(patient_id, current_user, db)
    return patient_to_fhir(p)


@router.get("/Patient/{patient_id}/Condition")
async def fhir_get_conditions(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(select(Condition).where(Condition.patient_id == patient_id))
    conditions = result.scalars().all()
    return {
        "resourceType": "Bundle",
        "type": "searchset",
        "total": len(conditions),
        "entry": [{"resource": condition_to_fhir(c)} for c in conditions],
    }


@router.get("/Patient/{patient_id}/Observation")
async def fhir_get_observations(
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    await get_scoped_patient(patient_id, current_user, db)
    result = await db.execute(select(LabResult).where(LabResult.patient_id == patient_id))
    labs = result.scalars().all()
    return {
        "resourceType": "Bundle",
        "type": "searchset",
        "total": len(labs),
        "entry": [{"resource": lab_to_fhir(l)} for l in labs],
    }
