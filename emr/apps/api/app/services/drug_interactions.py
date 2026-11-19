"""
Drug–drug interaction and allergy checking.

Primary source: NLM RxNav API (free, no key required):
  - /REST/rxcui.json?name=…            name → RxCUI
  - /REST/interaction/list.json        DDI check across a med list
RxNav has no PHI exposure — only drug names/RxCUIs are sent.

Fallback: a built-in table of well-known severe interactions, used when
RxNav is unreachable (offline/dev) so checks degrade rather than disappear.
"""
from __future__ import annotations

import logging

import httpx

logger = logging.getLogger(__name__)

RXNAV_BASE = "https://rxnav.nlm.nih.gov/REST"

# Well-known severe interactions (normalized lowercase ingredient pairs).
# Not exhaustive — a safety net for offline mode only.
_FALLBACK_SEVERE: dict[frozenset[str], str] = {
    frozenset({"warfarin", "aspirin"}): "Increased bleeding risk (anticoagulant + antiplatelet)",
    frozenset({"warfarin", "ibuprofen"}): "Increased bleeding risk; NSAIDs potentiate warfarin",
    frozenset({"warfarin", "amiodarone"}): "Amiodarone inhibits warfarin metabolism — INR rises",
    frozenset({"warfarin", "trimethoprim-sulfamethoxazole"}): "Marked INR elevation, bleeding risk",
    frozenset({"warfarin", "fluconazole"}): "CYP2C9 inhibition — major INR elevation",
    frozenset({"lisinopril", "spironolactone"}): "Hyperkalemia risk (ACE inhibitor + K-sparing diuretic)",
    frozenset({"lisinopril", "potassium chloride"}): "Hyperkalemia risk",
    frozenset({"digoxin", "amiodarone"}): "Amiodarone raises digoxin levels — toxicity risk",
    frozenset({"digoxin", "furosemide"}): "Hypokalemia from loop diuretic potentiates digoxin toxicity",
    frozenset({"metformin", "contrast media"}): "Lactic acidosis risk with iodinated contrast",
    frozenset({"simvastatin", "amiodarone"}): "Myopathy/rhabdomyolysis — limit simvastatin 20mg",
    frozenset({"simvastatin", "clarithromycin"}): "CYP3A4 inhibition — rhabdomyolysis risk",
    frozenset({"tramadol", "sertraline"}): "Serotonin syndrome risk",
    frozenset({"tramadol", "fluoxetine"}): "Serotonin syndrome risk",
    frozenset({"oxycodone", "lorazepam"}): "Opioid + benzodiazepine — respiratory depression (FDA boxed warning)",
    frozenset({"oxycodone", "alprazolam"}): "Opioid + benzodiazepine — respiratory depression (FDA boxed warning)",
    frozenset({"hydrocodone", "lorazepam"}): "Opioid + benzodiazepine — respiratory depression (FDA boxed warning)",
    frozenset({"morphine", "lorazepam"}): "Opioid + benzodiazepine — respiratory depression (FDA boxed warning)",
    frozenset({"clopidogrel", "omeprazole"}): "Omeprazole reduces clopidogrel activation (CYP2C19)",
    frozenset({"methotrexate", "trimethoprim-sulfamethoxazole"}): "Additive antifolate toxicity — pancytopenia",
    frozenset({"lithium", "ibuprofen"}): "NSAIDs reduce lithium clearance — toxicity",
    frozenset({"lithium", "lisinopril"}): "ACE inhibitors raise lithium levels",
    frozenset({"amiodarone", "ciprofloxacin"}): "Additive QT prolongation — torsades risk",
    frozenset({"insulin", "metoprolol"}): "Beta-blockers mask hypoglycemia symptoms",
}


def _norm(name: str) -> str:
    return name.strip().lower()


async def _rxcui_for_name(client: httpx.AsyncClient, name: str) -> str | None:
    try:
        r = await client.get(f"{RXNAV_BASE}/rxcui.json", params={"name": name, "search": 2})
        ids = (r.json().get("idGroup") or {}).get("rxnormId") or []
        return ids[0] if ids else None
    except Exception:
        return None


async def check_interactions(medication_names: list[str]) -> dict:
    """Check a medication list for drug–drug interactions.

    Returns {"interactions": [{drug_a, drug_b, severity, description}], "source": "rxnav"|"builtin"}.
    """
    meds = [_norm(m) for m in medication_names if m and m.strip()]
    if len(meds) < 2:
        return {"interactions": [], "source": "none"}

    # Try RxNav first
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            rxcuis = {}
            for name in meds:
                cui = await _rxcui_for_name(client, name)
                if cui:
                    rxcuis[cui] = name
            if len(rxcuis) >= 2:
                r = await client.get(
                    f"{RXNAV_BASE}/interaction/list.json",
                    params={"rxcuis": "+".join(rxcuis.keys())},
                )
                found = []
                for group in (r.json().get("fullInteractionTypeGroup") or []):
                    for itype in group.get("fullInteractionType", []):
                        for pair in itype.get("interactionPair", []):
                            concepts = pair.get("interactionConcept", [])
                            names = [
                                c.get("minConceptItem", {}).get("name", "?")
                                for c in concepts[:2]
                            ]
                            found.append({
                                "drug_a": names[0] if names else "?",
                                "drug_b": names[1] if len(names) > 1 else "?",
                                "severity": pair.get("severity", "N/A"),
                                "description": pair.get("description", ""),
                            })
                return {"interactions": found, "source": "rxnav"}
    except Exception as exc:
        logger.warning("RxNav unreachable, falling back to builtin DDI table: %s", exc)

    # Builtin fallback
    found = []
    for i, a in enumerate(meds):
        for b in meds[i + 1:]:
            desc = _FALLBACK_SEVERE.get(frozenset({a, b}))
            if desc:
                found.append({
                    "drug_a": a,
                    "drug_b": b,
                    "severity": "high",
                    "description": desc,
                })
    return {"interactions": found, "source": "builtin"}


def check_allergies(medication_names: list[str], allergies: list[dict | str]) -> list[dict]:
    """Cross-check a med list against the patient's allergy list.

    Allergies may be strings or {"allergen": …} dicts (the Patient JSON shape).
    Substring matching both directions — catches 'penicillin' vs 'Penicillin VK'.
    """
    alerts = []
    allergens = []
    for a in allergies or []:
        allergen = a.get("allergen") if isinstance(a, dict) else a
        if allergen:
            allergens.append((_norm(allergen), a if isinstance(a, dict) else {}))
    for med in medication_names:
        m = _norm(med)
        for allergen, detail in allergens:
            if allergen in m or m in allergen:
                alerts.append({
                    "medication": med,
                    "allergen": allergen,
                    "reaction": detail.get("reaction"),
                    "severity": detail.get("severity") or "unknown",
                })
    return alerts
