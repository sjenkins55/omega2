from fastapi import FastAPI, Depends, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import get_settings
from app.db.base import engine, Base

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
    # Disable automatic /docs and /redoc in production to reduce attack surface
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

# Security + CORS middleware (order matters — security headers wrap everything)
from app.middleware.security import SecurityHeadersMiddleware, AuditLogMiddleware
app.add_middleware(AuditLogMiddleware)
app.add_middleware(SecurityHeadersMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-ADT-Key"],
)

# Ensure all models are registered so create_all picks them up
from app.models import territory as _t          # noqa: F401
from app.models import portal_message as _pm    # noqa: F401
from app.models import condition as _cond       # noqa: F401
from app.models import lab_result as _lr        # noqa: F401
from app.models import task as _task            # noqa: F401
from app.models import audit_event as _audit    # noqa: F401
from app.models import notification as _notif   # noqa: F401
from app.models import care_plan as _cp         # noqa: F401
from app.models import physician_order as _ord  # noqa: F401
from app.models import plan_of_care as _poc     # noqa: F401
from app.models import oasis as _oasis          # noqa: F401
from app.models import visit_photo as _vp       # noqa: F401
from app.models import eligibility as _elig     # noqa: F401
from app.models import adt_event as _adt        # noqa: F401
from app.models import organization as _org     # noqa: F401

from app.core.auth import get_current_user, get_current_patient
from app.api.routes import (
    patients, visits, ingestion, workflows, engagement, admin, auth, portal,
    conditions, lab_results, tasks, notifications, care_plans, orders, oasis,
    plan_of_care, reports, audit, visit_photos, eligibility, adt, fhir,
    vitals, discharge,
)


# ── ADT API key dependency ────────────────────────────────────────────────────

def verify_adt_api_key(x_adt_key: str | None = Header(None)):
    """
    Hospital systems sending ADT feeds must include X-ADT-Key header.
    If ADT_API_KEY is not configured, the endpoint is disabled.
    """
    adt_key = settings.adt_api_key
    if not adt_key:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="ADT inbound is not configured on this server (ADT_API_KEY not set)",
        )
    if x_adt_key != adt_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid ADT API key")


# ── Auth routes — no JWT required ────────────────────────────────────────────
app.include_router(auth.router, prefix="/api/v1")

# ── ADT inbound — API key required (no staff JWT) ────────────────────────────
app.include_router(adt.router, prefix="/api/v1", dependencies=[Depends(verify_adt_api_key)])

# ── Staff routes — require valid staff JWT ───────────────────────────────────
_staff_auth = [Depends(get_current_user)]
app.include_router(patients.router,      prefix="/api/v1", dependencies=_staff_auth)
app.include_router(visits.router,        prefix="/api/v1", dependencies=_staff_auth)
app.include_router(ingestion.router,     prefix="/api/v1", dependencies=_staff_auth)
app.include_router(workflows.router,     prefix="/api/v1", dependencies=_staff_auth)
app.include_router(engagement.router,    prefix="/api/v1", dependencies=_staff_auth)
app.include_router(admin.router,         prefix="/api/v1", dependencies=_staff_auth)
app.include_router(conditions.router,    prefix="/api/v1", dependencies=_staff_auth)
app.include_router(lab_results.router,   prefix="/api/v1", dependencies=_staff_auth)
app.include_router(tasks.router,         prefix="/api/v1", dependencies=_staff_auth)
app.include_router(notifications.router, prefix="/api/v1", dependencies=_staff_auth)
app.include_router(care_plans.router,    prefix="/api/v1", dependencies=_staff_auth)
app.include_router(orders.router,        prefix="/api/v1", dependencies=_staff_auth)
app.include_router(oasis.router,         prefix="/api/v1", dependencies=_staff_auth)
app.include_router(plan_of_care.router,  prefix="/api/v1", dependencies=_staff_auth)
app.include_router(reports.router,       prefix="/api/v1", dependencies=_staff_auth)
app.include_router(audit.router,         prefix="/api/v1", dependencies=_staff_auth)
app.include_router(visit_photos.router,  prefix="/api/v1", dependencies=_staff_auth)
app.include_router(eligibility.router,   prefix="/api/v1", dependencies=_staff_auth)
app.include_router(vitals.router,        prefix="/api/v1", dependencies=_staff_auth)
app.include_router(discharge.router,     prefix="/api/v1", dependencies=_staff_auth)
# FHIR R4 — 21st Century Cures mandates patient access; staff JWT required here,
# production should add SMART on FHIR / dedicated FHIR auth layer
app.include_router(fhir.router,          prefix="/api/v1", dependencies=_staff_auth)

# ── Patient portal routes — require portal JWT ───────────────────────────────
app.include_router(portal.router, prefix="/api/v1", dependencies=[Depends(get_current_patient)])


@app.get("/health")
async def health():
    return {"status": "ok", "version": settings.app_version}
