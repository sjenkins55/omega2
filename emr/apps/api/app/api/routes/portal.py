"""
Patient portal API — all routes require a portal JWT.
Patients can only see their own data.
"""
from __future__ import annotations
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.base import get_db
from app.core.auth import get_current_patient
from app.models.patient import Patient
from app.models.visit import Visit, VisitStatus
from app.models.portal_message import PortalMessage

router = APIRouter(prefix="/portal", tags=["portal"])


@router.get("/dashboard")
async def portal_dashboard(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    # Most recent completed visit for action items
    last_visit_q = (
        select(Visit)
        .where(Visit.patient_id == patient.id, Visit.status == VisitStatus.completed)
        .order_by(Visit.completed_at.desc())
        .limit(1)
    )
    result = await db.execute(last_visit_q)
    last_visit = result.scalar_one_or_none()

    # Next upcoming visit
    next_visit_q = (
        select(Visit)
        .where(Visit.patient_id == patient.id, Visit.status == VisitStatus.scheduled)
        .order_by(Visit.scheduled_at)
        .limit(1)
    )
    result = await db.execute(next_visit_q)
    next_visit = result.scalar_one_or_none()

    # Unread message count
    unread_q = select(PortalMessage).where(
        PortalMessage.patient_id == patient.id,
        PortalMessage.direction == "staff",
        PortalMessage.is_read == False,
    )
    unread_result = await db.execute(unread_q)
    unread_count = len(unread_result.scalars().all())

    # Translate risk score to friendly tier
    risk = patient.ai_risk_score or 0.0
    risk_tier = "high" if risk >= 0.7 else "moderate" if risk >= 0.4 else "low"
    risk_message = {
        "high": "Your care team has flagged some items to discuss at your next visit.",
        "moderate": "Your care team is keeping a close eye on your health.",
        "low": "You're doing well. Keep following your care plan.",
    }[risk_tier]

    return {
        "patient": {
            "name": f"{patient.first_name} {patient.last_name}",
            "first_name": patient.first_name,
            "mrn": patient.mrn,
            "date_of_birth": patient.date_of_birth.isoformat() if patient.date_of_birth else None,
            "phone": patient.phone,
            "address": patient.address,
        },
        "next_visit": _visit_summary(next_visit) if next_visit else None,
        "last_visit": _visit_summary(last_visit) if last_visit else None,
        "action_items": (last_visit.action_items or []) if last_visit else [],
        "diagnoses_count": len(patient.diagnoses or []) + (1 if patient.primary_dx else 0),
        "medications_count": len(patient.medications or []),
        "unread_messages": unread_count,
        "care_team": patient.care_team or [],
        "risk_tier": risk_tier,
        "risk_message": risk_message,
    }


@router.get("/visits")
async def portal_visits(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    upcoming_q = (
        select(Visit)
        .where(Visit.patient_id == patient.id, Visit.status == VisitStatus.scheduled)
        .order_by(Visit.scheduled_at)
        .limit(10)
    )
    past_q = (
        select(Visit)
        .where(Visit.patient_id == patient.id, Visit.status == VisitStatus.completed)
        .order_by(Visit.completed_at.desc())
        .limit(20)
    )
    up_result = await db.execute(upcoming_q)
    past_result = await db.execute(past_q)

    return {
        "upcoming": [_visit_summary(v) for v in up_result.scalars().all()],
        "past": [_visit_detail(v) for v in past_result.scalars().all()],
    }


@router.get("/records")
async def portal_records(patient: Patient = Depends(get_current_patient)):
    diagnoses = []
    if patient.primary_dx:
        diagnoses.append({"description": patient.primary_dx, "type": "primary"})
    for dx in (patient.diagnoses or []):
        diagnoses.append({"description": dx if isinstance(dx, str) else dx.get("description", ""), "type": "secondary"})

    return {
        "diagnoses": diagnoses,
        "medications": [
            {
                "name": m.get("name"),
                "dose": m.get("dose"),
                "frequency": m.get("frequency"),
                "route": m.get("route", "oral"),
            }
            for m in (patient.medications or [])
        ],
        "allergies": patient.allergies or [],
        "care_team": patient.care_team or [],
        "insurance": {
            "type": patient.insurance_type,
            "id": patient.insurance_id,
        },
    }


@router.get("/messages")
async def portal_messages(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PortalMessage)
        .where(PortalMessage.patient_id == patient.id)
        .order_by(PortalMessage.created_at.desc())
        .limit(50)
    )
    messages = result.scalars().all()

    # Mark staff messages as read
    for m in messages:
        if m.direction == "staff" and not m.is_read:
            m.is_read = True
    await db.commit()

    return {
        "messages": [
            {
                "id": str(m.id),
                "direction": m.direction,
                "sender_name": m.sender_name,
                "content": m.content,
                "is_read": m.is_read,
                "created_at": m.created_at.isoformat(),
            }
            for m in reversed(messages)
        ]
    }


class SendMessageBody(BaseModel):
    content: str


@router.post("/messages")
async def send_portal_message(
    body: SendMessageBody,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    if not body.content.strip():
        raise HTTPException(400, "Message cannot be empty")

    msg = PortalMessage(
        patient_id=patient.id,
        direction="patient",
        sender_name=f"{patient.first_name} {patient.last_name}",
        content=body.content.strip(),
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return {"id": str(msg.id), "created_at": msg.created_at.isoformat()}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _visit_summary(v: Visit) -> dict:
    return {
        "id": str(v.id),
        "visit_type": v.visit_type,
        "status": v.status,
        "scheduled_at": v.scheduled_at.isoformat() if v.scheduled_at else None,
        "completed_at": v.completed_at.isoformat() if v.completed_at else None,
    }


def _visit_detail(v: Visit) -> dict:
    return {
        **_visit_summary(v),
        "assessment": v.assessment,
        "plan": v.plan,
        "vital_signs": v.vital_signs or {},
        "action_items": v.action_items or [],
    }
