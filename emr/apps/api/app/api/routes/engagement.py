from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime, timezone
from app.db.base import get_db
from app.models.engagement import OutreachRecord, OutreachStatus
from app.models.patient import Patient
from app.models.user import UserRole
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row

router = APIRouter(prefix="/engagement", tags=["engagement"])


@router.get("/outreach")
async def list_outreach(
    patient_id: UUID | None = None,
    status: OutreachStatus | None = None,
    limit: int = 100,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(OutreachRecord)
    if current_user.role != UserRole.super_admin:
        query = query.join(Patient, OutreachRecord.patient_id == Patient.id, isouter=True).where(
            (Patient.organization_id == current_user.organization_id)
            | (Patient.organization_id.is_(None))
            | (OutreachRecord.patient_id.is_(None))
        )
    if patient_id:
        await get_scoped_patient(patient_id, current_user, db)
        query = query.where(OutreachRecord.patient_id == patient_id)
    if status:
        query = query.where(OutreachRecord.status == status)
    result = await db.execute(query.order_by(OutreachRecord.scheduled_at.desc()).limit(limit))
    return result.scalars().all()


@router.post("/outreach/compose")
async def compose_outreach_message(
    patient_id: UUID,
    outreach_type: str,
    channel: str,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Use AI to generate a personalized outreach message for this patient."""
    from app.modules.ai_engine.client import get_ai_client
    from app.core.config import get_settings
    import json

    settings = get_settings()
    patient = await get_scoped_patient(patient_id, current_user, db)

    client = get_ai_client()
    prompt = f"""Generate a warm, professional {outreach_type} outreach message via {channel} for this home care patient.

Patient: {patient.first_name} {patient.last_name}
Primary diagnoses: {patient.primary_dx}
Outreach type: {outreach_type}
Channel: {channel}

Keep it brief (under 160 chars for SMS, under 300 words for email).
Return JSON: {{"subject": "", "body": "", "personalization_notes": ""}}"""

    response = await client.messages.create(
        model=settings.ai_model,
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}],
    )
    try:
        return json.loads(response.content[0].text)
    except Exception:
        return {"body": response.content[0].text}


@router.post("/outreach/bulk-schedule")
async def bulk_schedule_outreach(
    outreach_type: str,
    channel: str,
    patient_ids: list[UUID],
    scheduled_at: datetime,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Schedule outreach for multiple patients at once."""
    records = []
    for pid in patient_ids:
        await get_scoped_patient(pid, current_user, db)
        rec = OutreachRecord(
            patient_id=pid,
            outreach_type=outreach_type,
            channel=channel,
            status=OutreachStatus.scheduled,
            scheduled_at=scheduled_at,
            ai_personalized=True,
        )
        db.add(rec)
        records.append(str(rec.id) if rec.id else "pending")
    await db.flush()
    return {"scheduled": len(records), "type": outreach_type}


@router.post("/outreach/{record_id}/send")
async def send_outreach(
    record_id: UUID,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(OutreachRecord).where(OutreachRecord.id == record_id))
    rec = result.scalar_one_or_none()
    if not rec:
        raise HTTPException(404, "Outreach record not found")
    org_id = (
        await db.execute(select(Patient.organization_id).where(Patient.id == rec.patient_id))
    ).scalar_one_or_none()
    if not can_access_org_row(org_id, current_user):
        raise HTTPException(404, "Outreach record not found")
    rec.status = OutreachStatus.sent
    rec.sent_at = datetime.now(timezone.utc)
    await db.flush()
    return {"sent": True}
