"""
End-to-end smoke test: auth → patient → schedule visit → progress note → verify.
Run with: python smoke_test.py
"""
import sys
import httpx

BASE = "http://localhost:8000/api/v1"
PASS = "\033[32m✓\033[0m"
FAIL = "\033[31m✗\033[0m"

def check(label, condition, detail=""):
    if condition:
        print(f"  {PASS} {label}")
    else:
        print(f"  {FAIL} {label}  {detail}")
        sys.exit(1)

print("\n=== EMR Smoke Test ===\n")

with httpx.Client(base_url=BASE, timeout=10) as c:

    # ── 1. Auth ────────────────────────────────────────────────────────────────
    print("1. Auth")
    r = c.post("/auth/login", json={"email": "admin@concertocare.com", "password": "admin123"})
    check("POST /auth/login → 200", r.status_code == 200, r.text)
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    check("access_token present", bool(token))

    # ── 2. Patient list ────────────────────────────────────────────────────────
    print("\n2. Patient list")
    r = c.get("/patients", headers=headers)
    check("GET /patients → 200", r.status_code == 200, r.text)
    patients = r.json()["patients"]
    check("At least 1 patient seeded", len(patients) >= 1)
    eleanor = next((p for p in patients if p["last_name"] == "Voss"), None)
    check("Eleanor Voss present", eleanor is not None)
    patient_id = eleanor["id"]
    check("ai_risk_score = 0.82", eleanor["ai_risk_score"] == 0.82)
    print(f"     patient_id: {patient_id}")

    # ── 3. High-risk filter ────────────────────────────────────────────────────
    print("\n3. High-risk filter")
    r = c.get("/patients?high_risk=true", headers=headers)
    check("GET /patients?high_risk=true → 200", r.status_code == 200)
    hr = r.json()["patients"]
    check("Eleanor appears in high-risk list", any(p["id"] == patient_id for p in hr))

    # ── 4. Get patient by ID ───────────────────────────────────────────────────
    print("\n4. Get patient")
    r = c.get(f"/patients/{patient_id}", headers=headers)
    check("GET /patients/{id} → 200", r.status_code == 200)
    p = r.json()
    check("soc_date present", p.get("soc_date") == "2026-01-15")
    check("code_status = dnr", p.get("code_status") == "dnr")
    check("advance_directives_on_file = true", p.get("advance_directives_on_file") is True)

    # ── 5. Schedule a visit (appointment) ─────────────────────────────────────
    print("\n5. Schedule visit")
    r = c.post("/visits", headers=headers, json={
        "patient_id": patient_id,
        "visit_type": "skilled_nursing",
        "scheduled_at": "2026-06-05T10:00:00Z",
    })
    check("POST /visits → 201", r.status_code == 201, r.text)
    visit = r.json()
    visit_id = visit["id"]
    check("status = scheduled", visit["status"] == "scheduled")
    check("visit_type = skilled_nursing", visit["visit_type"] == "skilled_nursing")
    print(f"     visit_id: {visit_id}")

    # ── 6. Add a progress note via POST /visits/{id}/notes ───────────────────
    print("\n6. Add progress note")
    r = c.post(f"/visits/{visit_id}/notes", headers=headers, json={
        "raw_note": "Patient alert and oriented x3. Weight 147 lbs (down 1 lb from baseline). "
                    "Bilateral pedal edema 1+. Lungs clear. BP 138/82. Reports medication adherence. "
                    "No chest pain or dyspnea at rest.",
        "vital_signs": {"bp": "138/82", "hr": 72, "rr": 16, "o2_sat": 97, "weight_lbs": 147.0, "temp_f": 98.2},
        "clinical_findings": {"edema": "1+ bilateral pedal", "lungs": "clear", "orientation": "x3"},
        "subjective": "Patient reports feeling well. No dyspnea. Compliant with Furosemide.",
        "objective": "Weight 147 lbs. BP 138/82. 1+ pedal edema bilateral. Lungs clear to auscultation.",
        "assessment": "HFrEF stable. Weight trending down, edema improving. Medication adherent.",
        "plan": "Continue current regimen. Daily weights. Return visit in 3 days.",
        "finalize": True,
    })
    check("POST /visits/{id}/notes → 200", r.status_code == 200, r.text)
    note_resp = r.json()
    check("note_finalized = true", note_resp.get("note_finalized") is True)

    # Fetch the visit to verify persisted fields
    r = c.get(f"/visits/{visit_id}", headers=headers)
    check("GET /visits/{id} → 200", r.status_code == 200)
    v = r.json()
    check("status updated to completed", v["status"] == "completed")
    check("vitals saved", v["vital_signs"]["weight_lbs"] == 147.0)
    check("SOAP note saved", "Furosemide" in (v["subjective"] or ""))

    # ── 7. Verify visit appears on patient's visit list ────────────────────────
    print("\n7. Verify visit list")
    r = c.get(f"/visits?patient_id={patient_id}", headers=headers)
    check("GET /visits?patient_id= → 200", r.status_code == 200, r.text)
    visits = r.json() if isinstance(r.json(), list) else r.json().get("visits", [])
    check("Visit appears in patient list", any(v["id"] == visit_id for v in visits))

    # ── 8. Conditions (HCC) ───────────────────────────────────────────────────
    print("\n8. Conditions / HCC")
    r = c.get(f"/patients/{patient_id}/conditions", headers=headers)
    check("GET /patients/{id}/conditions → 200", r.status_code == 200, r.text)
    conditions = r.json()
    check(f"5 conditions seeded", len(conditions) == 5)
    confirmed = [c for c in conditions if c["verification_status"] == "confirmed"]
    provisional = [c for c in conditions if c["verification_status"] == "provisional"]
    check("4 confirmed HCC conditions", len(confirmed) == 4)
    check("1 provisional (Particle Health suspect)", len(provisional) == 1)

    r = c.get(f"/patients/{patient_id}/conditions?hcc_only=true", headers=headers)
    check("?hcc_only=true filter works", r.status_code == 200 and all(c["hcc_code"] for c in r.json()))

    r = c.get(f"/patients/{patient_id}/conditions?unrecaptured=true", headers=headers)
    check("?unrecaptured=true filter works", r.status_code == 200)

    # ── 9. Lab results ────────────────────────────────────────────────────────
    print("\n9. Lab results")
    r = c.get(f"/patients/{patient_id}/lab-results", headers=headers)
    check("GET /patients/{id}/lab-results → 200", r.status_code == 200, r.text)
    labs = r.json()
    check("4 lab results seeded", len(labs) == 4)
    bnp = next((l for l in labs if l["display_name"] == "BNP"), None)
    check("BNP present with HH interpretation", bnp is not None and bnp["interpretation"] == "HH")
    egfr = next((l for l in labs if l["loinc_code"] == "33914-3"), None)
    check("eGFR 38 (low, consistent with CKD3)", egfr is not None and egfr["value_quantity"] == 38.0)

    # ── 10. Create new lab result manually ────────────────────────────────────
    print("\n10. Manual lab result entry")
    r = c.post(f"/patients/{patient_id}/lab-results", headers=headers, json={
        "source": "manual",
        "loinc_code": "2951-2",
        "display_name": "Sodium",
        "category": "laboratory",
        "value_quantity": 138.0,
        "unit": "mEq/L",
        "reference_range_low": 136.0,
        "reference_range_high": 145.0,
        "interpretation": "N",
        "status": "final",
        "collected_at": "2026-05-30T08:00:00Z",
    })
    check("POST /patients/{id}/lab-results → 201", r.status_code == 201, r.text)
    check("Sodium value saved", r.json()["value_quantity"] == 138.0)

    r = c.get(f"/patients/{patient_id}/lab-results", headers=headers)
    check("5 lab results now on file", len(r.json()) == 5)

    # ── 11. Confirm provisional HCC condition ─────────────────────────────────
    print("\n11. HCC gap closure — confirm provisional condition")
    prov = provisional[0]
    prov_id = prov["id"]
    check("Provisional from particle_health", prov["source"] == "particle_health")
    r = c.patch(f"/conditions/{prov_id}", headers=headers, json={
        "verification_status": "confirmed",
        "recaptured_in_year": 2026,
        "asserter_name": "Dr. James Whitfield",
        "asserter_npi": "1234567890",
    })
    check("PATCH /conditions/{id} → 200", r.status_code == 200, r.text)
    check("verification_status now confirmed", r.json()["verification_status"] == "confirmed")
    check("recaptured_in_year = 2026", r.json()["recaptured_in_year"] == 2026)

    r = c.get(f"/patients/{patient_id}/conditions?unrecaptured=true", headers=headers)
    check("No unrecaptured HCC gaps remain", len(r.json()) == 0)

print(f"\n{'='*40}")
print("All checks passed.")
print(f"{'='*40}\n")
