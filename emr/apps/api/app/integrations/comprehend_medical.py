"""
AWS Comprehend Medical client.
Extracts structured clinical entities from unstructured text:
  - detect_entities_v2  → medications, diagnoses, anatomy, test/treatment/procedure
  - infer_icd10_cm      → ICD-10-CM codes from clinical text
  - infer_rx_norm       → RxNorm codes from medication mentions

Used in the fax ingestion pipeline to enrich extracted_data
before patient matching and workflow triggering.
"""
from __future__ import annotations
import asyncio
import boto3
import structlog
from app.core.config import get_settings

log = structlog.get_logger()
settings = get_settings()

_cm_client = None


def _get_client():
    global _cm_client
    if _cm_client is None:
        session = boto3.Session(
            aws_access_key_id=settings.aws_access_key_id or None,
            aws_secret_access_key=settings.aws_secret_access_key or None,
            aws_session_token=settings.aws_session_token or None,
            region_name=settings.aws_region,
        )
        _cm_client = session.client("comprehendmedical")
    return _cm_client


async def extract_clinical_entities(text: str) -> dict:
    """
    Run all three Comprehend Medical models on the text.
    Returns a merged dict of entities, ICD-10 codes, and RxNorm codes.
    Chunks text >20k chars (Comprehend Medical limit per call).
    """
    if not settings.use_comprehend_medical:
        return {}

    chunks = _chunk_text(text, max_chars=19_000)
    all_entities: list[dict] = []
    all_icd10: list[dict] = []
    all_rxnorm: list[dict] = []

    client = _get_client()
    loop = asyncio.get_event_loop()

    for chunk in chunks:
        try:
            entities_resp, icd_resp, rx_resp = await asyncio.gather(
                loop.run_in_executor(None, lambda c=chunk: client.detect_entities_v2(Text=c)),
                loop.run_in_executor(None, lambda c=chunk: client.infer_icd10_cm(Text=c)),
                loop.run_in_executor(None, lambda c=chunk: client.infer_rx_norm(Text=c)),
            )
            all_entities.extend(entities_resp.get("Entities", []))
            all_icd10.extend(icd_resp.get("Entities", []))
            all_rxnorm.extend(rx_resp.get("Entities", []))
        except Exception as exc:
            log.warning("comprehend_medical_chunk_failed", error=str(exc))

    return {
        "entities":    _normalise_entities(all_entities),
        "icd10_codes": _normalise_icd10(all_icd10),
        "rxnorm_codes":_normalise_rxnorm(all_rxnorm),
        "medications": _extract_medications(all_entities),
        "diagnoses":   _extract_diagnoses(all_icd10),
        "lab_values":  _extract_labs(all_entities),
    }


def _chunk_text(text: str, max_chars: int) -> list[str]:
    if len(text) <= max_chars:
        return [text]
    chunks = []
    while text:
        chunk, text = text[:max_chars], text[max_chars:]
        # Try to break on sentence boundary
        last_period = chunk.rfind(". ")
        if last_period > max_chars * 0.8:
            text = chunk[last_period + 2:] + text
            chunk = chunk[:last_period + 1]
        chunks.append(chunk)
    return chunks


def _normalise_entities(entities: list[dict]) -> list[dict]:
    return [
        {
            "text": e.get("Text"),
            "category": e.get("Category"),
            "type": e.get("Type"),
            "score": round(e.get("Score", 0), 3),
            "traits": [t["Name"] for t in e.get("Traits", [])],
            "attributes": [
                {"type": a["Type"], "text": a["Text"]}
                for a in e.get("Attributes", [])
            ],
        }
        for e in entities
        if e.get("Score", 0) >= 0.6
    ]


def _normalise_icd10(entities: list[dict]) -> list[dict]:
    codes = []
    for e in entities:
        for concept in e.get("ICD10CMConcepts", []):
            if concept.get("Score", 0) >= 0.5:
                codes.append({
                    "code": concept["Code"],
                    "description": concept["Description"],
                    "score": round(concept["Score"], 3),
                    "text": e.get("Text"),
                })
    # Deduplicate by code, keep highest score
    seen: dict[str, dict] = {}
    for c in codes:
        if c["code"] not in seen or c["score"] > seen[c["code"]]["score"]:
            seen[c["code"]] = c
    return sorted(seen.values(), key=lambda x: x["score"], reverse=True)


def _normalise_rxnorm(entities: list[dict]) -> list[dict]:
    codes = []
    for e in entities:
        for concept in e.get("RxNormConcepts", []):
            if concept.get("Score", 0) >= 0.5:
                codes.append({
                    "rxnorm_code": concept["Code"],
                    "description": concept["Description"],
                    "score": round(concept["Score"], 3),
                    "text": e.get("Text"),
                })
    seen: dict[str, dict] = {}
    for c in codes:
        if c["rxnorm_code"] not in seen or c["score"] > seen[c["rxnorm_code"]]["score"]:
            seen[c["rxnorm_code"]] = c
    return sorted(seen.values(), key=lambda x: x["score"], reverse=True)


def _extract_medications(entities: list[dict]) -> list[dict]:
    meds = []
    for e in entities:
        if e.get("Category") == "MEDICATION" and e.get("Type") == "GENERIC_NAME":
            med: dict = {"name": e.get("Text"), "score": round(e.get("Score", 0), 3)}
            for attr in e.get("Attributes", []):
                if attr["Type"] == "DOSAGE":
                    med["dose"] = attr["Text"]
                elif attr["Type"] == "ROUTE_OR_MODE":
                    med["route"] = attr["Text"]
                elif attr["Type"] == "FREQUENCY":
                    med["frequency"] = attr["Text"]
                elif attr["Type"] == "STRENGTH":
                    med["strength"] = attr["Text"]
            if med.get("score", 0) >= 0.7:
                meds.append(med)
    return meds


def _extract_diagnoses(icd10_entities: list[dict]) -> list[dict]:
    return [
        {"code": e["code"], "description": e["description"], "text": e.get("text")}
        for e in icd10_entities[:20]
    ]


def _extract_labs(entities: list[dict]) -> list[dict]:
    labs = []
    for e in entities:
        if e.get("Category") == "TEST_TREATMENT_PROCEDURE" and e.get("Type") == "TEST_NAME":
            lab: dict = {"name": e.get("Text")}
            for attr in e.get("Attributes", []):
                if attr["Type"] == "TEST_VALUE":
                    lab["value"] = attr["Text"]
                elif attr["Type"] == "TEST_UNIT":
                    lab["unit"] = attr["Text"]
            if lab.get("score", 0) >= 0.6 or True:
                labs.append(lab)
    return labs[:30]
