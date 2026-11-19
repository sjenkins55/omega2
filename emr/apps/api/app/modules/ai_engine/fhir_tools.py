"""
Claude tool definitions for FHIR interactions.
Mirrors the MedAgentBench tool taxonomy: 6 read + 3 write operations.
"""
from typing import Any

FHIR_TOOLS: list[dict] = [
    {
        "name": "search_patient",
        "description": (
            "Search for a patient in the EHR by name, date of birth, MRN, or insurance ID. "
            "Returns demographic info including patient ID needed for subsequent queries."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "name":      {"type": "string", "description": "Patient full name or partial name"},
                "birthdate": {"type": "string", "description": "Date of birth in YYYY-MM-DD format"},
                "mrn":       {"type": "string", "description": "Medical record number"},
                "identifier":{"type": "string", "description": "Insurance ID or other identifier"},
            },
        },
    },
    {
        "name": "get_observations",
        "description": (
            "Retrieve lab results or vital signs for a patient. "
            "Use category='laboratory' for labs, category='vital-signs' for vitals. "
            "Optionally filter by LOINC code or date range."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "category"],
            "properties": {
                "patient_id": {"type": "string", "description": "FHIR patient ID"},
                "category":   {"type": "string", "enum": ["laboratory", "vital-signs"], "description": "Observation category"},
                "code":       {"type": "string", "description": "LOINC code for specific test (e.g. '2339-0' for blood glucose)"},
                "date_from":  {"type": "string", "description": "Start date YYYY-MM-DD"},
                "date_to":    {"type": "string", "description": "End date YYYY-MM-DD"},
                "limit":      {"type": "integer", "description": "Max results to return", "default": 10},
            },
        },
    },
    {
        "name": "get_conditions",
        "description": "Retrieve the patient's active problem list, diagnoses, and conditions.",
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {
                "patient_id": {"type": "string"},
                "category":   {"type": "string", "description": "Filter: 'problem-list-item' or 'encounter-diagnosis'"},
                "status":     {"type": "string", "description": "Filter: 'active', 'inactive', 'resolved'"},
            },
        },
    },
    {
        "name": "get_medications",
        "description": (
            "Retrieve active or historical medication orders and reconciled meds. "
            "Returns medication name, dose, frequency, route, and prescriber."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {
                "patient_id": {"type": "string"},
                "status":     {"type": "string", "description": "Filter: 'active', 'completed', 'stopped'"},
                "category":   {"type": "string", "description": "'inpatient', 'outpatient', 'community', 'discharge'"},
                "date_from":  {"type": "string"},
            },
        },
    },
    {
        "name": "get_procedures",
        "description": "Retrieve completed procedures, surgeries, and clinical activities.",
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {
                "patient_id": {"type": "string"},
                "date_from":  {"type": "string"},
                "date_to":    {"type": "string"},
                "code":       {"type": "string", "description": "CPT code filter"},
            },
        },
    },
    {
        "name": "get_visit_history",
        "description": "Retrieve recent home visit notes, assessments, and structured visit data from this EMR.",
        "input_schema": {
            "type": "object",
            "required": ["patient_id"],
            "properties": {
                "patient_id": {"type": "string"},
                "limit":      {"type": "integer", "default": 5, "description": "Number of recent visits to retrieve"},
                "visit_type": {"type": "string", "description": "Filter by type: skilled_nursing, physical_therapy, etc."},
            },
        },
    },
    {
        "name": "record_vital_signs",
        "description": (
            "Write vital sign measurements to the patient's flowsheet. "
            "Use this to document vitals taken during a visit."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "vitals"],
            "properties": {
                "patient_id": {"type": "string"},
                "recorded_at": {"type": "string", "description": "ISO datetime of measurement"},
                "vitals": {
                    "type": "object",
                    "description": "Vital sign values",
                    "properties": {
                        "bp_systolic":  {"type": "number"},
                        "bp_diastolic": {"type": "number"},
                        "heart_rate":   {"type": "number"},
                        "respiratory_rate": {"type": "number"},
                        "temperature":  {"type": "number"},
                        "o2_saturation":{"type": "number"},
                        "weight_kg":    {"type": "number"},
                        "pain_score":   {"type": "integer", "minimum": 0, "maximum": 10},
                    },
                },
            },
        },
    },
    {
        "name": "draft_medication_order",
        "description": (
            "Create a draft medication order for clinician review. "
            "This does NOT auto-sign — it creates a pending order requiring clinician approval."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "medication_name", "dose", "frequency", "route"],
            "properties": {
                "patient_id":      {"type": "string"},
                "medication_name": {"type": "string"},
                "rxnorm_code":     {"type": "string", "description": "RxNorm code if known"},
                "dose":            {"type": "string", "description": "e.g. '40mg'"},
                "frequency":       {"type": "string", "description": "e.g. 'daily', 'BID', 'PRN'"},
                "route":           {"type": "string", "description": "e.g. 'oral', 'IV', 'topical'"},
                "indication":      {"type": "string"},
                "notes":           {"type": "string"},
            },
        },
    },
    {
        "name": "draft_service_request",
        "description": (
            "Create a draft referral or service order for clinician review. "
            "Covers lab orders, imaging, specialist referrals, and therapy orders. "
            "Requires clinician signature before activation."
        ),
        "input_schema": {
            "type": "object",
            "required": ["patient_id", "service_type", "description"],
            "properties": {
                "patient_id":   {"type": "string"},
                "service_type": {"type": "string", "description": "e.g. 'lab', 'imaging', 'referral', 'therapy'"},
                "description":  {"type": "string", "description": "What is being ordered"},
                "cpt_code":     {"type": "string"},
                "priority":     {"type": "string", "enum": ["routine", "urgent", "stat"], "default": "routine"},
                "reason":       {"type": "string"},
                "notes":        {"type": "string"},
            },
        },
    },
]

# Lookup by name for the executor
TOOL_MAP: dict[str, dict] = {t["name"]: t for t in FHIR_TOOLS}
