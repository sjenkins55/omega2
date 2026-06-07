from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.db.base import get_db
from app.models.visit_photo import VisitPhoto
from app.models.visit import Visit

router = APIRouter(tags=["visit_photos"])


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
async def list_photos(visit_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")
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
):
    result = await db.execute(select(Visit).where(Visit.id == visit_id))
    visit = result.scalar_one_or_none()
    if not visit:
        raise HTTPException(404, "Visit not found")

    # In production: upload to S3 and get the key.
    # Here we store the filename as the key (replace with real S3 logic).
    import uuid as uuid_mod
    s3_key = f"visit-photos/{visit_id}/{uuid_mod.uuid4()}_{file.filename}"

    measurements = None
    if any(v is not None for v in [length_cm, width_cm, depth_cm]):
        measurements = {k: v for k, v in {"length_cm": length_cm, "width_cm": width_cm, "depth_cm": depth_cm}.items() if v is not None}

    photo = VisitPhoto(
        visit_id=visit_id,
        patient_id=visit.patient_id,
        s3_key=s3_key,
        file_name=file.filename or "photo.jpg",
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
async def delete_photo(photo_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(VisitPhoto).where(VisitPhoto.id == photo_id))
    photo = result.scalar_one_or_none()
    if not photo:
        raise HTTPException(404, "Photo not found")
    await db.delete(photo)
