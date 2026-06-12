from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import date, datetime, timedelta, timezone
from app.db.base import get_db
from app.models.patient import Patient, PatientStatus
from app.models.visit import Visit, VisitStatus
from app.models.condition import Condition
from app.models.user import UserRole
from app.core.auth import get_current_user, org_scope

router = APIRouter(prefix="/reports", tags=["reports"])


def _org_filter_via_patient(query, model, current_user):
    """Join an aggregate query through Patient and restrict to the user's org."""
    if current_user.role == UserRole.super_admin:
        return query
    return query.join(Patient, model.patient_id == Patient.id, isouter=True).where(
        (Patient.organization_id == current_user.organization_id)
        | (Patient.organization_id.is_(None))
        | (model.patient_id.is_(None))
    )


@router.get("/census")
async def census_report(
    days: int = Query(30, le=365),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Active patient census and risk distribution."""
    active_q = org_scope(select(Patient).where(Patient.status == PatientStatus.active), Patient, current_user)
    patients = (await db.execute(active_q)).scalars().all()
    total = len(patients)
    high_risk = sum(1 for p in patients if (p.ai_risk_score or 0) >= 0.7)
    critical = sum(1 for p in patients if (p.ai_risk_score or 0) >= 0.9)

    since = datetime.now(timezone.utc) - timedelta(days=days)
    new_admissions = sum(1 for p in patients if p.soc_date and p.soc_date >= since.date())
    discharges_q = org_scope(
        select(func.count()).select_from(Patient)
        .where(Patient.status == PatientStatus.discharged, Patient.discharge_date >= since.date()),
        Patient,
        current_user,
    )
    discharges = (await db.execute(discharges_q)).scalar()

    return {
        "period_days": days,
        "active_patients": total,
        "high_risk": high_risk,
        "critical": critical,
        "new_admissions": new_admissions,
        "discharges": discharges,
        "risk_distribution": {
            "low": sum(1 for p in patients if (p.ai_risk_score or 0) < 0.4),
            "moderate": sum(1 for p in patients if 0.4 <= (p.ai_risk_score or 0) < 0.7),
            "high": high_risk - critical,
            "critical": critical,
        },
    }


@router.get("/visit-utilization")
async def visit_utilization(
    days: int = Query(30, le=365),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Completed vs. scheduled visits over the period."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    query = _org_filter_via_patient(
        select(Visit).where(Visit.scheduled_at >= since), Visit, current_user
    )
    visits = (await db.execute(query)).scalars().all()

    by_status: dict[str, int] = {}
    by_type: dict[str, int] = {}
    for v in visits:
        by_status[v.status] = by_status.get(v.status, 0) + 1
        by_type[v.visit_type] = by_type.get(v.visit_type, 0) + 1

    completed = by_status.get("completed", 0)
    total = len(visits)
    return {
        "period_days": days,
        "total_visits": total,
        "completed": completed,
        "missed": by_status.get("missed", 0),
        "cancelled": by_status.get("cancelled", 0),
        "completion_rate": round(completed / total, 3) if total else 0,
        "by_visit_type": by_type,
    }


@router.get("/hcc-capture")
async def hcc_capture_report(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """HCC gap closure rate for the current year."""
    current_year = date.today().year
    query = _org_filter_via_patient(
        select(Condition).where(Condition.hcc_code.isnot(None)), Condition, current_user
    )
    all_hcc = (await db.execute(query)).scalars().all()

    total = len(all_hcc)
    recaptured = sum(1 for c in all_hcc if c.recaptured_in_year == current_year)
    provisional = sum(1 for c in all_hcc if c.verification_status == "provisional")

    return {
        "year": current_year,
        "total_hcc_conditions": total,
        "recaptured_this_year": recaptured,
        "capture_rate": round(recaptured / total, 3) if total else 0,
        "provisional_suspects": provisional,
        "gap_count": total - recaptured,
    }


@router.get("/hospitalization-risk")
async def hospitalization_risk(
    threshold: float = Query(0.7, ge=0.0, le=1.0),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Patients above the given risk score threshold."""
    query = org_scope(
        select(Patient)
        .where(Patient.status == PatientStatus.active, Patient.ai_risk_score >= threshold)
        .order_by(Patient.ai_risk_score.desc()),
        Patient,
        current_user,
    )
    patients = (await db.execute(query)).scalars().all()

    return {
        "threshold": threshold,
        "count": len(patients),
        "patients": [
            {
                "id": str(p.id),
                "name": f"{p.first_name} {p.last_name}",
                "mrn": p.mrn,
                "risk_score": p.ai_risk_score,
                "primary_dx": p.primary_dx,
                "soc_date": p.soc_date.isoformat() if p.soc_date else None,
            }
            for p in patients
        ],
    }


@router.get("/staff-productivity")
async def staff_productivity(
    days: int = Query(30, le=365),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Completed visits per clinician over the period."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    query = _org_filter_via_patient(
        select(Visit).where(
            Visit.status == VisitStatus.completed,
            Visit.completed_at >= since,
        ),
        Visit,
        current_user,
    )
    visits = (await db.execute(query)).scalars().all()

    by_clinician: dict[str, int] = {}
    for v in visits:
        key = str(v.clinician_id) if v.clinician_id else "unassigned"
        by_clinician[key] = by_clinician.get(key, 0) + 1

    return {
        "period_days": days,
        "total_completed": len(visits),
        "by_clinician": by_clinician,
    }
