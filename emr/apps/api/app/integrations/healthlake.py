"""
AWS HealthLake FHIR R4 client.
Uses SigV4-signed HTTP requests to the HealthLake FHIR endpoint.
Falls back to local DB when HEALTHLAKE_DATASTORE_ID is not set.

HealthLake endpoint:
  https://healthlake.{region}.amazonaws.com/datastore/{datastore_id}/r4/
"""
from __future__ import annotations
import json
from datetime import datetime, timezone
from typing import Any
import httpx
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials
import structlog

from app.core.config import get_settings

log = structlog.get_logger()
settings = get_settings()


class HealthLakeClient:
    """
    Async FHIR R4 client backed by AWS HealthLake.
    All methods return raw FHIR resource dicts or FHIR Bundle dicts.
    """

    def __init__(self):
        self._endpoint = (
            settings.healthlake_endpoint
            or f"https://healthlake.{settings.aws_region}.amazonaws.com"
              f"/datastore/{settings.healthlake_datastore_id}/r4"
        )
        self._credentials = self._load_credentials()
        self._region = settings.aws_region

    def _load_credentials(self) -> Credentials | None:
        try:
            session = boto3.Session(
                aws_access_key_id=settings.aws_access_key_id or None,
                aws_secret_access_key=settings.aws_secret_access_key or None,
                aws_session_token=settings.aws_session_token or None,
                region_name=settings.aws_region,
            )
            return session.get_credentials().resolve()
        except Exception as exc:
            log.warning("healthlake_credentials_failed", error=str(exc))
            return None

    def _sign_request(self, method: str, url: str, body: str | None = None) -> dict:
        """Return SigV4-signed headers for a HealthLake request."""
        aws_req = AWSRequest(
            method=method,
            url=url,
            data=body or "",
            headers={"Content-Type": "application/fhir+json"},
        )
        SigV4Auth(self._credentials, "healthlake", self._region).add_auth(aws_req)
        return dict(aws_req.headers)

    async def _get(self, path: str, params: dict | None = None) -> dict:
        url = f"{self._endpoint}/{path.lstrip('/')}"
        headers = self._sign_request("GET", url)
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(url, headers=headers, params=params)
            resp.raise_for_status()
            return resp.json()

    async def _post(self, path: str, resource: dict) -> dict:
        url = f"{self._endpoint}/{path.lstrip('/')}"
        body = json.dumps(resource)
        headers = self._sign_request("POST", url, body)
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, headers=headers, content=body)
            resp.raise_for_status()
            return resp.json()

    # ── Read operations ────────────────────────────────────────────────────

    async def search_patient(
        self,
        name: str | None = None,
        birthdate: str | None = None,
        identifier: str | None = None,
        mrn: str | None = None,
    ) -> dict:
        params: dict[str, str] = {}
        if name:
            params["name"] = name
        if birthdate:
            params["birthdate"] = birthdate
        if identifier or mrn:
            params["identifier"] = identifier or mrn
        bundle = await self._get("Patient", params)
        return _parse_bundle(bundle, "Patient")

    async def get_observations(
        self,
        patient_id: str,
        category: str = "laboratory",
        code: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        limit: int = 10,
    ) -> dict:
        params: dict[str, str] = {
            "patient": patient_id,
            "category": category,
            "_count": str(limit),
            "_sort": "-date",
        }
        if code:
            params["code"] = code
        if date_from:
            params["date"] = f"ge{date_from}"
        if date_to:
            params["date"] = f"le{date_to}"
        bundle = await self._get("Observation", params)
        return _parse_bundle(bundle, "Observation")

    async def get_conditions(
        self,
        patient_id: str,
        category: str | None = "problem-list-item",
        status: str | None = "active",
    ) -> dict:
        params: dict[str, str] = {"patient": patient_id}
        if category:
            params["category"] = category
        if status:
            params["clinical-status"] = status
        bundle = await self._get("Condition", params)
        return _parse_bundle(bundle, "Condition")

    async def get_medications(
        self,
        patient_id: str,
        status: str | None = "active",
        category: str | None = None,
    ) -> dict:
        params: dict[str, str] = {"patient": patient_id}
        if status:
            params["status"] = status
        if category:
            params["category"] = category
        bundle = await self._get("MedicationRequest", params)
        return _parse_bundle(bundle, "MedicationRequest")

    async def get_procedures(
        self,
        patient_id: str,
        date_from: str | None = None,
        code: str | None = None,
    ) -> dict:
        params: dict[str, str] = {"patient": patient_id, "_sort": "-date"}
        if date_from:
            params["date"] = f"ge{date_from}"
        if code:
            params["code"] = code
        bundle = await self._get("Procedure", params)
        return _parse_bundle(bundle, "Procedure")

    # ── Write operations (draft, pending clinician approval) ──────────────

    async def record_vital_signs(self, patient_id: str, vitals: dict, recorded_at: str | None = None) -> dict:
        ts = recorded_at or datetime.now(timezone.utc).isoformat()
        components = []
        loinc_map = {
            "bp_systolic":     ("8480-6",  "Systolic blood pressure",   "mm[Hg]"),
            "bp_diastolic":    ("8462-4",  "Diastolic blood pressure",  "mm[Hg]"),
            "heart_rate":      ("8867-4",  "Heart rate",                "/min"),
            "respiratory_rate":("9279-1",  "Respiratory rate",          "/min"),
            "temperature":     ("8310-5",  "Body temperature",          "Cel"),
            "o2_saturation":   ("59408-5", "Oxygen saturation",         "%"),
            "weight_kg":       ("29463-7", "Body weight",               "kg"),
        }
        for key, (code, display, unit) in loinc_map.items():
            if key in vitals and vitals[key] is not None:
                components.append({
                    "code": {"coding": [{"system": "http://loinc.org", "code": code, "display": display}]},
                    "valueQuantity": {"value": vitals[key], "unit": unit, "system": "http://unitsofmeasure.org"},
                })

        resource = {
            "resourceType": "Observation",
            "status": "final",
            "category": [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category",
                                       "code": "vital-signs"}]}],
            "code": {"coding": [{"system": "http://loinc.org", "code": "85353-1",
                                  "display": "Vital signs panel"}]},
            "subject": {"reference": f"Patient/{patient_id}"},
            "effectiveDateTime": ts,
            "component": components,
        }
        if vitals.get("pain_score") is not None:
            resource["component"].append({
                "code": {"coding": [{"system": "http://loinc.org", "code": "72514-3",
                                     "display": "Pain severity - 0-10 verbal numeric scale"}]},
                "valueInteger": int(vitals["pain_score"]),
            })
        return await self._post("Observation", resource)

    async def draft_medication_order(
        self,
        patient_id: str,
        medication_name: str,
        rxnorm_code: str | None,
        dose: str,
        frequency: str,
        route: str,
        indication: str | None = None,
        notes: str | None = None,
    ) -> dict:
        resource: dict[str, Any] = {
            "resourceType": "MedicationRequest",
            "status": "draft",
            "intent": "order",
            "medicationCodeableConcept": {
                "coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm",
                             "code": rxnorm_code or "", "display": medication_name}],
                "text": medication_name,
            },
            "subject": {"reference": f"Patient/{patient_id}"},
            "authoredOn": datetime.now(timezone.utc).isoformat(),
            "dosageInstruction": [{
                "text": f"{dose} {frequency} {route}",
                "route": {"text": route},
                "doseAndRate": [{"doseQuantity": {"text": dose}}],
            }],
        }
        if indication:
            resource["reasonCode"] = [{"text": indication}]
        if notes:
            resource["note"] = [{"text": notes}]
        return await self._post("MedicationRequest", resource)

    async def draft_service_request(
        self,
        patient_id: str,
        service_type: str,
        description: str,
        cpt_code: str | None = None,
        priority: str = "routine",
        reason: str | None = None,
        notes: str | None = None,
    ) -> dict:
        resource: dict[str, Any] = {
            "resourceType": "ServiceRequest",
            "status": "draft",
            "intent": "order",
            "priority": priority,
            "category": [{"text": service_type}],
            "code": {
                "coding": [{"system": "http://www.ama-assn.org/go/cpt",
                             "code": cpt_code or "", "display": description}],
                "text": description,
            },
            "subject": {"reference": f"Patient/{patient_id}"},
            "authoredOn": datetime.now(timezone.utc).isoformat(),
        }
        if reason:
            resource["reasonCode"] = [{"text": reason}]
        if notes:
            resource["note"] = [{"text": notes}]
        return await self._post("ServiceRequest", resource)


# ── Helpers ────────────────────────────────────────────────────────────────

def _parse_bundle(bundle: dict, resource_type: str) -> dict:
    """Extract resources from a FHIR Bundle and return a clean list."""
    entries = bundle.get("entry", [])
    resources = [e["resource"] for e in entries if e.get("resource", {}).get("resourceType") == resource_type]
    return {"resources": resources, "total": bundle.get("total", len(resources))}


# ── Singleton ──────────────────────────────────────────────────────────────

_client: HealthLakeClient | None = None


def get_healthlake_client() -> HealthLakeClient | None:
    """Return client only if HealthLake is configured."""
    if not settings.healthlake_datastore_id:
        return None
    global _client
    if _client is None:
        _client = HealthLakeClient()
    return _client
