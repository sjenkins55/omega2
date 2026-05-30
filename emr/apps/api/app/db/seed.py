"""Seed the database with starter workflows and a demo patient."""
import asyncio
import uuid
from datetime import date, datetime, timezone
from app.db.base import AsyncSessionLocal, engine, Base
from app.models.workflow import Workflow, WorkflowStatus, TriggerType
from app.models.patient import Patient, PatientStatus, InsuranceType
from app.models.condition import Condition
from app.models.lab_result import LabResult
from app.models.user import User, UserRole
from passlib.context import CryptContext

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

SYSTEM_WORKFLOWS = [
    {
        "name": "Post-Visit Follow-up",
        "description": "24h after a visit completes: send SMS check-in, create follow-up task.",
        "trigger_type": TriggerType.visit_completed,
        "status": WorkflowStatus.active,
        "steps": [
            {"id": "w1", "type": "wait", "config": {"hours": 24}, "next_steps": ["w2"], "is_root": True},
            {"id": "w2", "type": "send_notification", "config": {"channel": "sms", "template": "post_visit_checkin"}, "next_steps": ["w3"]},
            {"id": "w3", "type": "create_task", "config": {"title": "Review post-visit patient response", "due_in_hours": 48, "priority": "normal"}, "next_steps": []},
        ],
    },
    {
        "name": "Critical Lab Result Alert",
        "description": "When a lab result with a critical flag is ingested, alert the care team immediately.",
        "trigger_type": TriggerType.lab_result_received,
        "status": WorkflowStatus.active,
        "steps": [
            {"id": "c1", "type": "send_notification", "config": {"channel": "push", "template": "critical_lab_alert"}, "next_steps": ["c2"], "is_root": True},
            {"id": "c2", "type": "create_task", "config": {"title": "Review critical lab result", "due_in_hours": 4, "priority": "urgent"}, "next_steps": []},
        ],
    },
    {
        "name": "Discharge → Home Care Onboarding",
        "description": "When a patient is discharged to home care, trigger onboarding: welcome message, initial visit scheduling, AI risk scoring.",
        "trigger_type": TriggerType.patient_discharged,
        "status": WorkflowStatus.active,
        "steps": [
            {"id": "d1", "type": "send_notification", "config": {"channel": "sms", "template": "welcome_home_care"}, "next_steps": ["d2"], "is_root": True},
            {"id": "d2", "type": "schedule_visit", "config": {"visit_type": "skilled_nursing", "days_from_now": 1}, "next_steps": ["d3"]},
            {"id": "d3", "type": "ai_analysis", "config": {}, "next_steps": []},
        ],
    },
    {
        "name": "High-Risk Patient Monthly Outreach",
        "description": "Every 30 days, send a personalized check-in to high-risk patients.",
        "trigger_type": TriggerType.scheduled,
        "status": WorkflowStatus.active,
        "trigger_config": {"cron": "0 9 1 * *"},
        "conditions": [{"field": "ai_risk_score", "operator": "gt", "value": 0.7}],
        "steps": [
            {"id": "r1", "type": "send_notification", "config": {"channel": "phone", "template": "high_risk_monthly"}, "next_steps": [], "is_root": True},
        ],
    },
]


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        # Create admin user
        from sqlalchemy import select
        existing_user = await db.execute(select(User).where(User.email == "admin@concertocare.com"))
        if not existing_user.scalar_one_or_none():
            admin = User(
                email="admin@concertocare.com",
                hashed_password=pwd_ctx.hash("admin123"),
                first_name="Admin",
                last_name="User",
                role=UserRole.admin,
            )
            db.add(admin)

        # Seed system workflows
        for wf_data in SYSTEM_WORKFLOWS:
            wf = Workflow(
                name=wf_data["name"],
                description=wf_data.get("description"),
                trigger_type=wf_data["trigger_type"],
                status=wf_data.get("status", WorkflowStatus.active),
                trigger_config=wf_data.get("trigger_config", {}),
                conditions=wf_data.get("conditions", []),
                steps=wf_data["steps"],
                is_system=True,
            )
            db.add(wf)

        # Demo patient
        demo_id = uuid.uuid4()
        demo = Patient(
            id=demo_id,
            mrn="CC-00001",
            first_name="Eleanor",
            last_name="Voss",
            date_of_birth=date(1942, 3, 14),
            gender="Female",
            phone="555-0142",
            status=PatientStatus.active,
            insurance_type=InsuranceType.medicare,
            insurance_id="1EV4298001A",
            insurance_plan_name="Medicare Part A & B",
            primary_dx="Heart failure with reduced ejection fraction (HFrEF)",
            diagnoses=[
                {"icd10_code": "I50.20", "description": "HFrEF, unspecified", "is_primary": True, "is_active": True},
                {"icd10_code": "E11.65", "description": "Type 2 Diabetes with hyperglycemia", "is_primary": False, "is_active": True},
                {"icd10_code": "N18.3", "description": "Chronic kidney disease, stage 3", "is_primary": False, "is_active": True},
                {"icd10_code": "I10", "description": "Essential hypertension", "is_primary": False, "is_active": True},
            ],
            medications=[
                {"name": "Furosemide", "dose": "40 mg", "route": "oral", "frequency": "daily", "is_active": True},
                {"name": "Metoprolol succinate", "dose": "25 mg", "route": "oral", "frequency": "daily", "is_active": True},
                {"name": "Lisinopril", "dose": "10 mg", "route": "oral", "frequency": "daily", "is_active": True},
                {"name": "Metformin", "dose": "500 mg", "route": "oral", "frequency": "BID", "is_active": True},
            ],
            allergies=[
                {"allergen": "Penicillin", "reaction": "Rash", "severity": "moderate"},
                {"allergen": "Sulfa", "reaction": "Unknown", "severity": "unknown"},
            ],
            care_team=[
                {"name": "Dr. James Whitfield", "role": "physician", "npi": "1234567890", "organization": "Whitfield Internal Medicine"},
            ],
            emergency_contact={"name": "Margaret Voss", "phone": "555-0199", "relationship": "daughter"},
            living_situation="alone",
            code_status="dnr",
            baseline_weight_lbs=148.0,
            advance_directives_on_file=True,
            functional_limitations={
                "ambulation": "requires_assistance",
                "bathing": "requires_assistance",
                "dressing": "independent",
                "toileting": "independent",
                "feeding": "independent",
            },
            soc_date=date(2026, 1, 15),
            certification_from=date(2026, 1, 15),
            certification_through=date(2026, 3, 15),
            referral_source="St. Mary's Hospital",
            referring_physician_name="Dr. James Whitfield",
            referring_physician_npi="1234567890",
            ai_risk_score=0.82,
            ai_risk_factors=[
                {"factor": "Recent hospitalization", "weight": 0.4, "description": "Admitted 3 weeks ago for AHF exacerbation"},
                {"factor": "Multiple comorbidities", "weight": 0.3, "description": "HFrEF + DM + CKD compound risk"},
                {"factor": "Age 83", "weight": 0.2, "description": "Advanced age increases frailty risk"},
            ],
        )
        db.add(demo)
        await db.flush()

        # Seed Condition records (HCC-mapped)
        conditions = [
            Condition(
                patient_id=demo_id,
                icd10_code="I50.20",
                icd10_description="Heart failure with reduced ejection fraction (HFrEF), unspecified",
                hcc_code="225",
                hcc_description="Heart Failure",
                clinical_status="active",
                verification_status="confirmed",
                is_primary=True,
                source="provider_entered",
                recaptured_in_year=2026,
                recorded_date=date(2026, 1, 15),
                asserter_name="Dr. James Whitfield",
                asserter_npi="1234567890",
            ),
            Condition(
                patient_id=demo_id,
                icd10_code="N18.3",
                icd10_description="Chronic kidney disease, stage 3 (moderate)",
                hcc_code="326",
                hcc_description="Chronic Kidney Disease, Stage 3, 4, or 5",
                clinical_status="active",
                verification_status="confirmed",
                is_primary=False,
                source="provider_entered",
                recaptured_in_year=2026,
                recorded_date=date(2026, 1, 15),
                asserter_name="Dr. James Whitfield",
                asserter_npi="1234567890",
            ),
            Condition(
                patient_id=demo_id,
                icd10_code="E11.65",
                icd10_description="Type 2 diabetes mellitus with hyperglycemia",
                hcc_code="37",
                hcc_description="Diabetes with Chronic Complications",
                clinical_status="active",
                verification_status="confirmed",
                is_primary=False,
                source="provider_entered",
                recaptured_in_year=2026,
                recorded_date=date(2026, 1, 15),
                asserter_name="Dr. James Whitfield",
                asserter_npi="1234567890",
            ),
            Condition(
                patient_id=demo_id,
                icd10_code="I10",
                icd10_description="Essential (primary) hypertension",
                hcc_code=None,
                hcc_description=None,
                clinical_status="active",
                verification_status="confirmed",
                is_primary=False,
                source="provider_entered",
                recorded_date=date(2026, 1, 15),
                asserter_name="Dr. James Whitfield",
                asserter_npi="1234567890",
            ),
            # Particle Health suspect — not yet confirmed
            Condition(
                patient_id=demo_id,
                icd10_code="E11.22",
                icd10_description="Type 2 diabetes mellitus with diabetic chronic kidney disease, stage 3",
                hcc_code="18",
                hcc_description="Diabetes with Chronic Complications",
                clinical_status="active",
                verification_status="provisional",
                is_primary=False,
                source="particle_health",
                external_id="fhir-cond-prt-0042",
                recorded_date=date(2025, 11, 3),
                asserter_name="Dr. Priya Nair",
                raw_fhir={
                    "resourceType": "Condition",
                    "id": "fhir-cond-prt-0042",
                    "subject": {"reference": "Patient/prt-eleanor-voss"},
                    "code": {"coding": [{"system": "http://hl7.org/fhir/sid/icd-10-cm", "code": "E11.22"}]},
                },
            ),
        ]
        for c in conditions:
            db.add(c)

        # Seed LabResult records
        lab_results = [
            LabResult(
                patient_id=demo_id,
                source="particle_health",
                loinc_code="2160-0",
                display_name="Creatinine",
                category="laboratory",
                value_quantity=1.8,
                unit="mg/dL",
                reference_range_low=0.6,
                reference_range_high=1.2,
                interpretation="H",
                status="final",
                collected_at=datetime(2026, 5, 10, 8, 0, tzinfo=timezone.utc),
                resulted_at=datetime(2026, 5, 10, 14, 30, tzinfo=timezone.utc),
                performing_lab="Quest Diagnostics",
                ordering_provider="Dr. James Whitfield",
                external_id="obs-prt-cr-001",
            ),
            LabResult(
                patient_id=demo_id,
                source="particle_health",
                loinc_code="33914-3",
                display_name="eGFR (CKD-EPI)",
                category="laboratory",
                value_quantity=38.0,
                unit="mL/min/1.73m2",
                reference_range_low=60.0,
                reference_range_high=None,
                interpretation="L",
                status="final",
                collected_at=datetime(2026, 5, 10, 8, 0, tzinfo=timezone.utc),
                resulted_at=datetime(2026, 5, 10, 14, 30, tzinfo=timezone.utc),
                performing_lab="Quest Diagnostics",
                ordering_provider="Dr. James Whitfield",
                external_id="obs-prt-egfr-001",
            ),
            LabResult(
                patient_id=demo_id,
                source="particle_health",
                loinc_code="4548-4",
                display_name="HbA1c",
                category="laboratory",
                value_quantity=7.9,
                unit="%",
                reference_range_low=None,
                reference_range_high=7.0,
                interpretation="H",
                status="final",
                collected_at=datetime(2026, 4, 2, 8, 0, tzinfo=timezone.utc),
                resulted_at=datetime(2026, 4, 2, 12, 0, tzinfo=timezone.utc),
                performing_lab="LabCorp",
                ordering_provider="Dr. James Whitfield",
                external_id="obs-prt-a1c-001",
            ),
            LabResult(
                patient_id=demo_id,
                source="particle_health",
                loinc_code="42637-9",
                display_name="BNP",
                category="laboratory",
                value_quantity=820.0,
                unit="pg/mL",
                reference_range_low=None,
                reference_range_high=100.0,
                interpretation="HH",
                status="final",
                collected_at=datetime(2026, 5, 5, 10, 0, tzinfo=timezone.utc),
                resulted_at=datetime(2026, 5, 5, 15, 0, tzinfo=timezone.utc),
                performing_lab="St. Mary's Hospital Lab",
                ordering_provider="Dr. James Whitfield",
                external_id="obs-prt-bnp-001",
            ),
        ]
        for lr in lab_results:
            db.add(lr)

        await db.commit()
        print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
