"""
Demo dataset: 9 providers + 100 patients spread across 4 states, with
addresses (lat/lng for geography-aware scheduling), conditions, meds,
risk scores, and a realistic visit schedule.

Everything lands in the same demo organization, so the admin account
(admin@concertocare.com, org-wide access) sees all of it.

Run AFTER the base seed:
    docker compose exec api python -m app.db.seed_demo

Idempotent: skips if the org already has 50+ patients.
"""
import asyncio
import random
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select, func
from passlib.context import CryptContext

from app.db.base import AsyncSessionLocal, engine, Base
from app.models.organization import Organization, PlanTier
from app.models.user import User, UserRole
from app.models.patient import Patient, PatientStatus, InsuranceType
from app.models.condition import Condition
from app.models.visit import Visit, VisitStatus, VisitType
from app.models import (  # noqa: F401 — register all mappers
    document, engagement, territory, portal_message, integration_key,
    lab_result, task, workflow, notification, physician_order, care_plan,
    oasis, plan_of_care, eligibility, adt_event, audit_event, visit_photo,
)
from app.services.hcc_mapping import map_icd10_to_hcc

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
rng = random.Random(42)

DEMO_PROVIDER_PASSWORD = "ConcertoDemo1!"

# city, state, zip, lat, lng
CITIES = [
    ("Austin", "TX", "78704", 30.245, -97.755),
    ("Round Rock", "TX", "78664", 30.508, -97.679),
    ("San Antonio", "TX", "78212", 29.467, -98.499),
    ("Los Angeles", "CA", "90026", 34.077, -118.264),
    ("Pasadena", "CA", "91101", 34.147, -118.144),
    ("Miami", "FL", "33133", 25.730, -80.243),
    ("Fort Lauderdale", "FL", "33301", 26.121, -80.137),
    ("Brooklyn", "NY", "11215", 40.662, -73.986),
    ("Queens", "NY", "11375", 40.721, -73.846),
]

PROVIDERS = [
    # email-stub, first, last, role, licensed_states, home city index, npi
    ("sarah.chen",     "Sarah",   "Chen",     UserRole.nurse,            ["TX"],       0, "1740283947"),
    ("marcus.webb",    "Marcus",  "Webb",     UserRole.nurse,            ["TX"],       2, "1841592637"),
    ("elena.reyes",    "Elena",   "Reyes",    UserRole.therapist,        ["TX"],       0, "1932475829"),
    ("david.okafor",   "David",   "Okafor",   UserRole.nurse,            ["CA"],       3, "1023948576"),
    ("priya.nair",     "Priya",   "Nair",     UserRole.physician,        ["CA", "TX"], 4, "1129384756"),
    ("james.holt",     "James",   "Holt",     UserRole.therapist,        ["CA"],       3, "1239485761"),
    ("ana.morales",    "Ana",     "Morales",  UserRole.nurse,            ["FL"],       5, "1349586712"),
    ("robert.kim",     "Robert",  "Kim",      UserRole.social_worker,    ["FL", "NY"], 6, "1459687123"),
    ("nicole.adams",   "Nicole",  "Adams",    UserRole.nurse,            ["NY"],       7, "1569788234"),
]

FIRST_NAMES_F = ["Margaret", "Dorothy", "Helen", "Ruth", "Betty", "Gloria", "Joan", "Carmen", "Rosa", "Evelyn",
                 "Frances", "Martha", "Alice", "Lucille", "Edith", "Pearl", "Vera", "Stella", "Irene", "Hazel"]
FIRST_NAMES_M = ["Harold", "Walter", "Ernest", "Raymond", "Eugene", "Howard", "Frank", "Leonard", "Ralph", "Stanley",
                 "Herman", "Clarence", "Vernon", "Chester", "Willie", "Roy", "Earl", "Albert", "Hector", "Otis"]
LAST_NAMES = ["Johnson", "Williams", "Rodriguez", "Garcia", "Martinez", "Davis", "Lopez", "Gonzalez", "Wilson",
              "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
              "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
              "Wright", "Torres", "Nguyen", "Hill", "Flores", "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera"]
STREETS = ["Oak St", "Maple Ave", "Cedar Ln", "Elm Dr", "Pine Rd", "Birch Ct", "Willow Way", "Magnolia Blvd",
           "Sunset Dr", "Riverside Ave", "Hillcrest Rd", "Meadow Ln", "Lakeview Dr", "Garden St", "Highland Ave"]

# (icd10, description, [meds])
DX_PROFILES = [
    ("I50.22", "Chronic systolic (congestive) heart failure",
     [{"name": "Furosemide", "dose": "40 mg", "route": "oral", "frequency": "daily", "is_active": True},
      {"name": "Carvedilol", "dose": "6.25 mg", "route": "oral", "frequency": "BID", "is_active": True}]),
    ("E11.9", "Type 2 diabetes mellitus without complications",
     [{"name": "Metformin", "dose": "1000 mg", "route": "oral", "frequency": "BID", "is_active": True}]),
    ("E11.40", "Type 2 diabetes with diabetic neuropathy",
     [{"name": "Metformin", "dose": "500 mg", "route": "oral", "frequency": "BID", "is_active": True},
      {"name": "Gabapentin", "dose": "300 mg", "route": "oral", "frequency": "TID", "is_active": True}]),
    ("J44.1", "COPD with acute exacerbation",
     [{"name": "Tiotropium", "dose": "18 mcg", "route": "inhaled", "frequency": "daily", "is_active": True},
      {"name": "Albuterol", "dose": "90 mcg", "route": "inhaled", "frequency": "PRN", "is_active": True}]),
    ("N18.4", "Chronic kidney disease, stage 4",
     [{"name": "Lisinopril", "dose": "10 mg", "route": "oral", "frequency": "daily", "is_active": True}]),
    ("I63.9", "Cerebral infarction (stroke), sequelae",
     [{"name": "Clopidogrel", "dose": "75 mg", "route": "oral", "frequency": "daily", "is_active": True},
      {"name": "Atorvastatin", "dose": "40 mg", "route": "oral", "frequency": "daily", "is_active": True}]),
    ("M81.0", "Age-related osteoporosis, s/p hip fracture",
     [{"name": "Alendronate", "dose": "70 mg", "route": "oral", "frequency": "weekly", "is_active": True},
      {"name": "Calcium + D3", "dose": "600 mg", "route": "oral", "frequency": "BID", "is_active": True}]),
    ("G30.9", "Alzheimer's disease, unspecified",
     [{"name": "Donepezil", "dose": "10 mg", "route": "oral", "frequency": "daily", "is_active": True}]),
    ("I48.91", "Atrial fibrillation, unspecified",
     [{"name": "Apixaban", "dose": "5 mg", "route": "oral", "frequency": "BID", "is_active": True},
      {"name": "Metoprolol", "dose": "50 mg", "route": "oral", "frequency": "daily", "is_active": True}]),
    ("L89.314", "Pressure ulcer of sacral region, stage 4",
     [{"name": "Cephalexin", "dose": "500 mg", "route": "oral", "frequency": "QID", "is_active": True}]),
]

ALLERGY_POOL = [
    [], [], [],  # most patients: none
    [{"allergen": "Penicillin", "reaction": "Rash", "severity": "moderate"}],
    [{"allergen": "Sulfa", "reaction": "Hives", "severity": "moderate"}],
    [{"allergen": "Codeine", "reaction": "Nausea", "severity": "mild"}],
    [{"allergen": "Latex", "reaction": "Contact dermatitis", "severity": "mild"}],
]

ROLE_VISIT_TYPE = {
    UserRole.nurse: VisitType.skilled_nursing,
    UserRole.physician: VisitType.skilled_nursing,
    UserRole.therapist: VisitType.physical_therapy,
    UserRole.social_worker: VisitType.social_work,
    UserRole.aide: VisitType.aide,
    UserRole.care_coordinator: VisitType.telehealth,
}


async def seed_demo():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        org = (await db.execute(
            select(Organization).where(Organization.slug == "concertocare-demo")
        )).scalar_one_or_none()
        if not org:
            org = Organization(name="ConcertoCare Demo", slug="concertocare-demo", plan_tier=PlanTier.professional)
            db.add(org)
            await db.flush()

        patient_count = (await db.execute(
            select(func.count(Patient.id)).where(Patient.organization_id == org.id)
        )).scalar()
        if patient_count and patient_count >= 50:
            print(f"Org already has {patient_count} patients — skipping demo seed.")
            return

        # ── Providers ────────────────────────────────────────────────────────
        providers: list[User] = []
        for stub, first, last, role, lic_states, city_idx, npi in PROVIDERS:
            email = f"{stub}@concertocare.com"
            existing = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
            if existing:
                providers.append(existing)
                continue
            city, state, zip_, lat, lng = CITIES[city_idx]
            u = User(
                email=email,
                hashed_password=pwd_ctx.hash(DEMO_PROVIDER_PASSWORD),
                first_name=first,
                last_name=last,
                role=role,
                npi=npi,
                licensed_states=lic_states,
                organization_id=org.id,
                preferences={
                    "home_city": city, "home_state": state,
                    "home_lat": lat, "home_lng": lng,
                    "service_radius_miles": 40,
                },
            )
            db.add(u)
            providers.append(u)
        await db.flush()
        print(f"Providers: {len(providers)} (password for all: {DEMO_PROVIDER_PASSWORD})")

        providers_by_state: dict[str, list[User]] = {}
        for u in providers:
            for s in u.licensed_states or []:
                providers_by_state.setdefault(s, []).append(u)

        # ── 100 patients ─────────────────────────────────────────────────────
        next_mrn = (patient_count or 0) + 2  # CC-00001 is the base-seed demo patient
        created_visits = 0
        now = datetime.now(timezone.utc)

        for i in range(100):
            city, state, zip_, base_lat, base_lng = rng.choice(CITIES)
            gender = rng.choice(["Female", "Male"])
            first = rng.choice(FIRST_NAMES_F if gender == "Female" else FIRST_NAMES_M)
            last = rng.choice(LAST_NAMES)
            dob = date(rng.randint(1935, 1958), rng.randint(1, 12), rng.randint(1, 28))
            dx_code, dx_desc, meds = rng.choice(DX_PROFILES)
            risk = round(min(0.97, max(0.05, rng.gauss(0.45, 0.22))), 2)
            status = PatientStatus.active if rng.random() < 0.88 else rng.choice(
                [PatientStatus.pending, PatientStatus.discharged]
            )
            soc = date.today() - timedelta(days=rng.randint(5, 50))

            in_state = providers_by_state.get(state, [])
            assigned = rng.choice(in_state) if in_state else None

            patient = Patient(
                id=uuid.uuid4(),
                mrn=f"CC-{next_mrn + i:05d}",
                organization_id=org.id,
                first_name=first,
                last_name=last,
                date_of_birth=dob,
                gender=gender,
                phone=f"555-{rng.randint(1000, 9999):04d}",
                status=status,
                address={
                    "line1": f"{rng.randint(100, 9899)} {rng.choice(STREETS)}",
                    "city": city, "state": state, "zip": zip_,
                    "lat": round(base_lat + rng.uniform(-0.09, 0.09), 4),
                    "lng": round(base_lng + rng.uniform(-0.09, 0.09), 4),
                },
                insurance_type=rng.choices(
                    [InsuranceType.medicare, InsuranceType.medicaid, InsuranceType.commercial],
                    weights=[70, 18, 12],
                )[0],
                insurance_id=f"{rng.randint(1, 9)}{''.join(rng.choices('ABCDEFGHJKMNPQRSTUVWXYZ', k=2))}{rng.randint(1000000, 9999999)}A",
                primary_dx=dx_desc,
                diagnoses=[{"icd10_code": dx_code, "description": dx_desc, "is_primary": True, "is_active": True}],
                medications=meds,
                allergies=rng.choice(ALLERGY_POOL),
                emergency_contact={"name": f"{rng.choice(FIRST_NAMES_F + FIRST_NAMES_M)} {last}",
                                   "phone": f"555-{rng.randint(1000, 9999):04d}",
                                   "relationship": rng.choice(["daughter", "son", "spouse", "niece", "neighbor"])},
                living_situation=rng.choice(["alone", "with_family", "with_spouse", "assisted_living"]),
                code_status=rng.choices(["full_code", "dnr"], weights=[60, 40])[0],
                baseline_weight_lbs=round(rng.uniform(110, 230), 1),
                soc_date=soc,
                certification_from=soc,
                certification_through=soc + timedelta(days=60),
                referral_source=rng.choice(["St. Mary's Hospital", "Memorial Hermann", "Cedars-Sinai",
                                            "Jackson Memorial", "NY Presbyterian", "Community PCP"]),
                assigned_provider_id=assigned.id if assigned else None,
                ai_risk_score=risk,
                ai_risk_factors=[{"factor": "Primary diagnosis", "weight": 0.4, "description": dx_desc}] if risk > 0.6 else [],
            )
            db.add(patient)
            await db.flush()

            # Condition row with auto-HCC
            hcc = map_icd10_to_hcc(dx_code)
            db.add(Condition(
                patient_id=patient.id,
                icd10_code=dx_code,
                icd10_description=dx_desc,
                hcc_code=hcc["hcc_code"] if hcc else None,
                hcc_description=hcc["description"] if hcc else None,
                clinical_status="active",
                verification_status="confirmed",
                is_primary=True,
                source="provider_entered",
                recorded_date=soc,
            ))

            # Visits: 1-2 completed in the past, ~70% get an upcoming one
            if assigned and status == PatientStatus.active:
                vtype = ROLE_VISIT_TYPE.get(assigned.role, VisitType.skilled_nursing)
                for _ in range(rng.randint(1, 2)):
                    past = now - timedelta(days=rng.randint(2, 21), hours=rng.randint(0, 8))
                    db.add(Visit(
                        patient_id=patient.id, clinician_id=assigned.id, visit_type=vtype,
                        status=VisitStatus.completed, scheduled_at=past,
                        started_at=past, completed_at=past + timedelta(minutes=45),
                        subjective=f"Patient reports stable symptoms related to {dx_desc.lower()}.",
                        objective="Vitals within baseline. Home environment safe.",
                        assessment=f"{dx_desc} — stable on current regimen.",
                        plan="Continue current medications. Next routine visit per care plan.",
                        structured_note={"subjective": "Stable", "assessment": f"{dx_desc} — stable"},
                        note_finalized=True, ai_processing_status="completed",
                    ))
                    created_visits += 1
                if rng.random() < 0.7:
                    upcoming = now + timedelta(days=rng.randint(1, 12))
                    upcoming = upcoming.replace(hour=rng.choice([8, 9, 10, 11, 13, 14, 15, 16]), minute=rng.choice([0, 30]), second=0, microsecond=0)
                    db.add(Visit(
                        patient_id=patient.id, clinician_id=assigned.id, visit_type=vtype,
                        status=VisitStatus.scheduled, scheduled_at=upcoming,
                    ))
                    created_visits += 1

        await db.commit()
        print(f"Created 100 patients across {len(CITIES)} cities and {created_visits} visits.")
        print("Provider logins (password: " + DEMO_PROVIDER_PASSWORD + "):")
        for stub, first, last, role, lic, _, _ in PROVIDERS:
            print(f"  {stub}@concertocare.com — {first} {last} ({role.value}, {'/'.join(lic)})")


if __name__ == "__main__":
    asyncio.run(seed_demo())
