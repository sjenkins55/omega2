"""Seed the database with starter workflows and a demo patient."""
import asyncio
import uuid
from datetime import date, datetime
from app.db.base import AsyncSessionLocal, engine, Base
from app.models.workflow import Workflow, WorkflowStatus, TriggerType
from app.models.patient import Patient, PatientStatus, InsuranceType
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
        existing_user = await db.execute(__import__("sqlalchemy", fromlist=["select"]).select(User).where(User.email == "admin@concertocare.com"))
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
        demo = Patient(
            mrn="CC-00001",
            first_name="Eleanor",
            last_name="Voss",
            date_of_birth=date(1942, 3, 14),
            gender="Female",
            phone="555-0142",
            status=PatientStatus.active,
            insurance_type=InsuranceType.medicare,
            insurance_id="1EV4298001A",
            primary_dx="Heart failure with reduced ejection fraction (HFrEF)",
            diagnoses=["HFrEF", "Type 2 Diabetes", "CKD Stage 3", "HTN"],
            medications=[
                {"name": "Furosemide", "dose": "40mg", "frequency": "daily"},
                {"name": "Metoprolol succinate", "dose": "25mg", "frequency": "daily"},
                {"name": "Lisinopril", "dose": "10mg", "frequency": "daily"},
                {"name": "Metformin", "dose": "500mg", "frequency": "BID"},
            ],
            allergies=["Penicillin", "Sulfa"],
            ai_risk_score=0.82,
            ai_risk_factors=[
                {"factor": "Recent hospitalization", "weight": 0.4, "description": "Admitted 3 weeks ago for AHF exacerbation"},
                {"factor": "Multiple comorbidities", "weight": 0.3, "description": "HFrEF + DM + CKD compound risk"},
                {"factor": "Age 83", "weight": 0.2, "description": "Advanced age increases frailty risk"},
            ],
        )
        db.add(demo)
        await db.commit()
        print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
