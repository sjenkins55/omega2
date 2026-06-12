import re
import uuid as uuid_mod
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.visit_photo import VisitPhoto
from app.models.visit import Visit
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row
from app.models.patient import Patient
from app.models.user import User

router = APIRouter(tags=["visit_photos"])

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
_SAFE_NAME_RE = re.compile(r"[^\w.\-]")


def _safe_filename(name: str) -> str:
    """Strip path separators and non-safe chars; truncate to 200 chars."""
    base = name.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    return _SAFE_NAME_RE.sub("_", base)[:200] or "photo.jpg"


class VisitPhotoResponse(BaseModel):
    id: UUID
    visit_id: UUID
    patient_id: UUID
    s3_key: str
    file_name: str
    caption: str | None = None
    wound_location: str | None = None
    wound_type: str | None = None
    measurements: dict | None = None
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("/visits/{visit_id}/photos", response_model=list[VisitPhotoResponse])
async def list_photos(
    visit_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")
    # Enforce org isolation through the visit's patient (404 on other-org)
    await get_scoped_patient(visit.patient_id, current_user, db)
    photos = await db.execute(
        select(VisitPhoto).where(VisitPhoto.visit_id == visit_id).order_by(VisitPhoto.created_at)
    )
    return photos.scalars().all()


@router.post("/visits/{visit_id}/photos", response_model=VisitPhotoResponse, status_code=201)
async def upload_photo(
    visit_id: UUID,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    wound_location: str | None = Form(None),
    wound_type: str | None = Form(None),
    length_cm: float | None = Form(None),
    width_cm: float | None = Form(None),
    depth_cm: float | None = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")

    # Enforce org isolation through the visit's patient (404 on other-org)
    patient = await get_scoped_patient(visit.patient_id, current_user, db)

    # Validate MIME type (server-side, not trusting client Content-Type)
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(415, f"Unsupported file type. Allowed: {', '.join(sorted(ALLOWED_MIME_TYPES))}")

    # Read and enforce size limit
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(413, f"File too large. Maximum size is {MAX_FILE_SIZE // (1024*1024)} MB")

    safe_name = _safe_filename(file.filename or "photo.jpg")
    org_prefix = str(patient.organization_id) if patient.organization_id else "shared"
    s3_key = f"{org_prefix}/visit-photos/{visit_id}/{uuid_mod.uuid4()}_{safe_name}"

    # TODO: upload `content` to S3 using s3_key

    measurements = None
    if any(v is not None for v in [length_cm, width_cm, depth_cm]):
        measurements = {k: v for k, v in {"length_cm": length_cm, "width_cm": width_cm, "depth_cm": depth_cm}.items() if v is not None}

    photo = VisitPhoto(
        visit_id=visit_id,
        patient_id=visit.patient_id,
        uploaded_by_id=current_user.id,
        s3_key=s3_key,
        file_name=safe_name,
        mime_type=file.content_type,
        caption=caption,
        wound_location=wound_location,
        wound_type=wound_type,
        measurements=measurements,
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)
    return photo


@router.delete("/visit-photos/{photo_id}", status_code=204)
async def delete_photo(
    photo_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(VisitPhoto).where(VisitPhoto.id == photo_id))
    photo = result.scalar_one_or_none()
    if not photo:
        raise HTTPException(404, "Photo not found")

    # Org isolation: 404 if the photo's patient belongs to another org
    patient_result = await db.execute(select(Patient).where(Patient.id == photo.patient_id))
    patient = patient_result.scalar_one_or_none()
    if patient and not can_access_org_row(patient.organization_id, current_user):
        raise HTTPException(404, "Photo not found")

    # Only the uploader or an admin may delete a wound photo
    from app.models.user import UserRole
    if photo.uploaded_by_id != current_user.id and current_user.role not in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(403, "Cannot delete another clinician's photo")

    await db.delete(photo)
