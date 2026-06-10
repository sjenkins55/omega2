"""
ICD-10-CM → CMS-HCC V28 mapping with RAF community weights.

This ships with a curated starter set covering the diagnoses most common in
home health / chronic care (CHF, COPD, diabetes, CKD, vascular, etc.).
For full coverage, load the complete CMS mapping file:
  https://www.cms.gov/medicare/payment/medicare-advantage-rates-statistics/risk-adjustment
into HCC_MAP via load_cms_file() — same shape, ~9,800 codes.

Matching: exact code first, then longest-prefix (ICD-10 family) match.
"""
from __future__ import annotations

import csv
from pathlib import Path

# {icd10_prefix: (hcc_code, description, raf_weight_community)}
# RAF weights are the V28 community, non-dual, aged factors.
_STARTER_MAP: dict[str, tuple[str, str, float]] = {
    # ── Diabetes ──────────────────────────────────────────────────────────
    "E1010": ("HCC37", "Diabetes with Severe Acute Complications", 0.302),
    "E1100": ("HCC38", "Diabetes with Glycemic, Unspecified, or No Complications", 0.166),
    "E119":  ("HCC38", "Diabetes with Glycemic, Unspecified, or No Complications", 0.166),
    "E1121": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1122": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1140": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1142": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1151": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1152": ("HCC36", "Diabetes with Chronic Complications", 0.302),
    "E1165": ("HCC38", "Diabetes with Glycemic, Unspecified, or No Complications", 0.166),
    "E1311": ("HCC37", "Diabetes with Severe Acute Complications", 0.302),
    # ── Heart failure ─────────────────────────────────────────────────────
    "I110":  ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I130":  ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I5021": ("HCC225", "Acute Heart Failure (Excludes Acute on Chronic)", 0.486),
    "I5022": ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I5023": ("HCC224", "Acute on Chronic Heart Failure", 0.572),
    "I5031": ("HCC225", "Acute Heart Failure (Excludes Acute on Chronic)", 0.486),
    "I5032": ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I5033": ("HCC224", "Acute on Chronic Heart Failure", 0.572),
    "I5041": ("HCC225", "Acute Heart Failure (Excludes Acute on Chronic)", 0.486),
    "I5042": ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I5043": ("HCC224", "Acute on Chronic Heart Failure", 0.572),
    "I509":  ("HCC226", "Heart Failure, Except End-Stage and Acute", 0.306),
    "I5084": ("HCC223", "Heart Failure with Heart Assist Device/Artificial Heart", 1.500),
    # ── Cardiac arrhythmias ───────────────────────────────────────────────
    "I480":  ("HCC238", "Specified Heart Arrhythmias", 0.299),
    "I481":  ("HCC238", "Specified Heart Arrhythmias", 0.299),
    "I482":  ("HCC238", "Specified Heart Arrhythmias", 0.299),
    "I4891": ("HCC238", "Specified Heart Arrhythmias", 0.299),
    "I493":  ("HCC238", "Specified Heart Arrhythmias", 0.299),
    # ── COPD / pulmonary ──────────────────────────────────────────────────
    "J430":  ("HCC280", "COPD", 0.319),
    "J439":  ("HCC280", "COPD", 0.319),
    "J440":  ("HCC280", "COPD", 0.319),
    "J441":  ("HCC280", "COPD", 0.319),
    "J449":  ("HCC280", "COPD", 0.319),
    "J9610": ("HCC276", "Chronic Respiratory Failure", 0.382),
    "J9611": ("HCC276", "Chronic Respiratory Failure", 0.382),
    "J9620": ("HCC276", "Chronic Respiratory Failure", 0.382),
    "J84112": ("HCC279", "Fibrosis of Lung and Other Lung Disorders", 0.319),
    # ── Chronic kidney disease ────────────────────────────────────────────
    "N183":  ("HCC329", "Chronic Kidney Disease, Moderate (Stage 3B)", 0.127),
    "N1830": ("HCC330", "Chronic Kidney Disease, Moderate (Stage 3, Except 3B)", 0.127),
    "N1831": ("HCC330", "Chronic Kidney Disease, Moderate (Stage 3, Except 3B)", 0.127),
    "N1832": ("HCC329", "Chronic Kidney Disease, Moderate (Stage 3B)", 0.127),
    "N184":  ("HCC328", "Chronic Kidney Disease, Severe (Stage 4)", 0.319),
    "N185":  ("HCC327", "Chronic Kidney Disease, Stage 5", 0.453),
    "N186":  ("HCC326", "Dialysis Status", 0.575),
    "Z992":  ("HCC326", "Dialysis Status", 0.575),
    # ── Vascular ──────────────────────────────────────────────────────────
    "I7025": ("HCC263", "Atherosclerosis of Arteries of the Extremities with Ulceration or Gangrene", 1.413),
    "I7092": ("HCC264", "Vascular Disease", 0.270),
    "I739":  ("HCC264", "Vascular Disease", 0.270),
    "I872":  ("HCC264", "Vascular Disease", 0.270),
    # ── Stroke / neuro ────────────────────────────────────────────────────
    "I6350": ("HCC253", "Ischemic or Unspecified Stroke", 0.166),
    "I639":  ("HCC253", "Ischemic or Unspecified Stroke", 0.166),
    "G20":   ("HCC196", "Parkinson and Other Degenerative Disease of Basal Ganglia", 0.524),
    "G300":  ("HCC127", "Dementia, Mild or Unspecified", 0.341),
    "G301":  ("HCC127", "Dementia, Mild or Unspecified", 0.341),
    "G309":  ("HCC127", "Dementia, Mild or Unspecified", 0.341),
    "F0280": ("HCC127", "Dementia, Mild or Unspecified", 0.341),
    "F0281": ("HCC125", "Dementia, Severe", 0.873),
    "G35":   ("HCC198", "Multiple Sclerosis", 0.585),
    "G8220": ("HCC182", "Paraplegia", 1.068),
    "G8250": ("HCC180", "Quadriplegia", 1.234),
    # ── Pressure ulcers / wounds (major home-health drivers) ──────────────
    "L89154": ("HCC379", "Pressure Ulcer of Skin with Necrosis Through to Muscle, Tendon, or Bone", 2.028),
    "L89153": ("HCC380", "Chronic Ulcer of Skin, Except Pressure, Through to Bone or Muscle", 1.069),
    "L89152": ("HCC381", "Pressure Pre-Ulcer Skin Changes or Unspecified Stage", 0.459),
    "L89151": ("HCC381", "Pressure Pre-Ulcer Skin Changes or Unspecified Stage", 0.459),
    "L97":    ("HCC383", "Chronic Ulcer of Skin, Except Pressure, Not Specified as Through to Bone or Muscle", 0.515),
    # ── Malnutrition ──────────────────────────────────────────────────────
    "E43":   ("HCC21", "Severe Protein-Calorie Malnutrition", 0.713),
    "E440":  ("HCC22", "Moderate Protein-Calorie Malnutrition", 0.713),
    "E441":  ("HCC22", "Moderate Protein-Calorie Malnutrition", 0.713),
    "E46":   ("HCC23", "Other Protein-Calorie Malnutrition", 0.207),
    # ── Cancer (common) ───────────────────────────────────────────────────
    "C3490": ("HCC19", "Lung and Other Severe Cancers", 1.150),
    "C50911": ("HCC21A", "Breast, Lung, and Other Cancers and Tumors", 0.300),
    "C61":   ("HCC22A", "Prostate, Breast, and Other Cancers and Tumors", 0.153),
    "C189":  ("HCC20", "Colorectal, Breast (Age < 50), Kidney, and Other Cancers", 0.643),
    # ── Behavioral ────────────────────────────────────────────────────────
    "F329":  ("HCC155", "Major Depressive Disorder, Mild or Unspecified", 0.299),
    "F332":  ("HCC154", "Major Depressive, Bipolar, and Paranoid Disorders", 0.299),
    "F209":  ("HCC151", "Schizophrenia", 0.524),
    # ── Substance use ─────────────────────────────────────────────────────
    "F1020": ("HCC139", "Alcohol Use Disorder, Moderate/Severe, or Dependence", 0.243),
    "F1120": ("HCC135", "Drug Use Disorder, Moderate/Severe, or Dependence", 0.243),
    # ── Liver ─────────────────────────────────────────────────────────────
    "K7460": ("HCC27", "Cirrhosis of Liver", 0.421),
    "K7290": ("HCC26", "Acute Liver Failure/Disease, Including Neonatal Hepatitis", 0.421),
    # ── Rheumatoid / immune ───────────────────────────────────────────────
    "M0600": ("HCC94", "Rheumatoid Arthritis and Other Specified Inflammatory Rheumatic Disorders", 0.421),
    "M0579": ("HCC94", "Rheumatoid Arthritis and Other Specified Inflammatory Rheumatic Disorders", 0.421),
    # ── Hip fracture (common SOC reason) ──────────────────────────────────
    "S72001": ("HCC404", "Hip Fracture/Dislocation", 0.350),
    "S72002": ("HCC404", "Hip Fracture/Dislocation", 0.350),
    # ── Morbid obesity ────────────────────────────────────────────────────
    "E6601": ("HCC48", "Morbid Obesity", 0.186),
    "Z6841": ("HCC48", "Morbid Obesity", 0.186),
    "Z6842": ("HCC48", "Morbid Obesity", 0.186),
}

HCC_MAP: dict[str, tuple[str, str, float]] = dict(_STARTER_MAP)


def _normalize(code: str) -> str:
    return code.replace(".", "").replace(" ", "").upper()


def map_icd10_to_hcc(icd10_code: str) -> dict | None:
    """Return {"hcc_code", "description", "raf_weight"} or None if the code
    doesn't risk-adjust. Exact match first, then longest-prefix family match."""
    code = _normalize(icd10_code)
    if not code:
        return None
    if code in HCC_MAP:
        hcc, desc, raf = HCC_MAP[code]
        return {"hcc_code": hcc, "description": desc, "raf_weight": raf}
    for length in range(len(code) - 1, 2, -1):
        prefix = code[:length]
        if prefix in HCC_MAP:
            hcc, desc, raf = HCC_MAP[prefix]
            return {"hcc_code": hcc, "description": desc, "raf_weight": raf}
    return None


def compute_raf(hcc_codes: list[str]) -> float:
    """Sum of RAF weights for a unique set of HCC codes (simplified — does not
    apply hierarchical exclusions or interaction terms)."""
    weights = {hcc: raf for (hcc, _desc, raf) in HCC_MAP.values()}
    return round(sum(weights.get(h, 0.0) for h in set(hcc_codes)), 3)


def load_cms_file(path: str | Path) -> int:
    """Load the full CMS V28 mapping CSV (columns: icd10, hcc, description, raf).
    Returns the number of codes loaded. Call at startup if the file exists."""
    count = 0
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            HCC_MAP[_normalize(row["icd10"])] = (
                row["hcc"],
                row.get("description", ""),
                float(row.get("raf", 0) or 0),
            )
            count += 1
    return count
