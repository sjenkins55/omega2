import asyncio
import re
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from app.db.base import get_db
from app.core.auth import get_current_user, get_scoped_patient, can_access_org_row
from app.models.document import Document, DocumentStatus, DocumentType
from app.models.patient import Patient
from app.models.user import User, UserRole

router = APIRouter(prefix="/ingestion", tags=["ingestion"])

ALLOWED_UPLOAD_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/tiff",
    "image/webp",
    "text/plain",
}
MAX_UPLOAD_SIZE = 50 * 1024 * 1024  # 50 MB
_SAFE_NAME_RE = re.compile(r"[^\w.\-]")


def _safe_filename(name: str) -> str:
    base = (name or "document").rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    return _SAFE_NAME_RE.sub("_", base)[:255] or "document"


def _org_prefix(org_id) -> str:
    """S3 key prefix for tenant isolation ("shared" for org-less rows)."""
    return str(org_id) if org_id else "shared"


async def _get_accessible_document(doc_id: UUID, user: User, db: AsyncSession) -> Document:
    """Load a document enforcing org isolation via the linked patient.

    Unassigned documents (no patient_id) are visible org-wide. Documents
    linked to another org's patient 404 to avoid leaking existence.
    """
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Document not found")
    if doc.patient_id is not None:
        patient_result = await db.execute(select(Patient).where(Patient.id == doc.patient_id))
        patient = patient_result.scalar_one_or_none()
        if patient and not can_access_org_row(patient.organization_id, user):
            raise HTTPException(404, "Document not found")
    return doc


@router.post("/fax/webhook")
async def receive_fax_webhook(
    fax_sid: str = Form(...),
    from_number: str = Form(...),
    to_number: str = Form(...),
    media_url: str = Form(...),
    num_pages: int = Form(1),
    db: AsyncSession = Depends(get_db),
):
    """Twilio Fax webhook — creates a Document record and queues processing."""
    doc = Document(
        doc_type="fax",
        status=DocumentStatus.received,
        source="twilio_fax",
        source_fax_number=from_number,
        file_name=f"fax_{fax_sid}.pdf",
        s3_key=f"{_org_prefix(None)}/faxes/{fax_sid}.pdf",
        mime_type="application/pdf",
        page_count=num_pages,
    )
    db.add(doc)
    await db.flush()
    await db.refresh(doc)

    from app.modules.ingestion.tasks import process_document_task
    process_document_task.delay(str(doc.id), media_url)

    return {"received": True, "document_id": str(doc.id)}


@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    patient_id: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Manual document upload — staff can upload PDFs, images, etc."""
    if file.content_type not in ALLOWED_UPLOAD_TYPES:
        raise HTTPException(415, f"Unsupported file type. Allowed: {', '.join(sorted(ALLOWED_UPLOAD_TYPES))}")

    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(413, f"File too large. Maximum size is {MAX_UPLOAD_SIZE // (1024*1024)} MB")

    patient = None
    if patient_id:
        patient = await get_scoped_patient(UUID(patient_id), current_user, db)
    org_id = patient.organization_id if patient else current_user.organization_id

    import boto3
    from app.core.config import get_settings
    settings = get_settings()

    safe_name = _safe_filename(file.filename or "document")
    s3_key = f"{_org_prefix(org_id)}/uploads/{safe_name}"

    def _upload_to_s3() -> None:
        s3 = boto3.client(
            "s3",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            region_name=settings.aws_region,
        )
        s3.put_object(Bucket=settings.s3_bucket, Key=s3_key, Body=content, ContentType=file.content_type)

    await asyncio.to_thread(_upload_to_s3)

    doc = Document(
        patient_id=patient.id if patient else None,
        doc_type="other",
        status=DocumentStatus.received,
        source="manual_upload",
        file_name=safe_name,
        s3_key=s3_key,
        mime_type=file.content_type or "application/octet-stream",
    )
    db.add(doc)
    await db.flush()
    await db.refresh(doc)

    from app.modules.ingestion.tasks import process_document_task
    process_document_task.delay(str(doc.id), None)

    return {"document_id": str(doc.id), "status": "queued"}


@router.get("/documents")
async def list_documents(
    patient_id: UUID | None = None,
    status: DocumentStatus | None = None,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Document)
    if patient_id:
        await get_scoped_patient(patient_id, current_user, db)
        query = query.where(Document.patient_id == patient_id)
    elif current_user.role != UserRole.super_admin:
        # Unassigned documents are visible org-wide; patient-linked documents
        # only when the patient belongs to the user's org (or no org — legacy).
        query = query.outerjoin(Patient, Document.patient_id == Patient.id).where(
            (Document.patient_id.is_(None))
            | (Patient.organization_id == current_user.organization_id)
            | (Patient.organization_id.is_(None))
        )
    if status:
        query = query.where(Document.status == status)
    result = await db.execute(query.order_by(Document.received_at.desc()).limit(limit))
    return result.scalars().all()


@router.get("/documents/{doc_id}")
async def get_document(
    doc_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await _get_accessible_document(doc_id, current_user, db)


class DocumentPatch(BaseModel):
    filename: str | None = None
    patient_id: UUID | None = None
    doc_type: DocumentType | None = None
    status: DocumentStatus | None = None


@router.patch("/documents/{doc_id}")
async def update_document(
    doc_id: UUID,
    body: DocumentPatch,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doc = await _get_accessible_document(doc_id, current_user, db)
    fields = body.model_dump(exclude_unset=True)

    if "filename" in fields and fields["filename"] is not None:
        doc.file_name = _safe_filename(fields["filename"])
    if "patient_id" in fields:
        if fields["patient_id"] is not None:
            patient = await get_scoped_patient(fields["patient_id"], current_user, db)
            doc.patient_id = patient.id
        else:
            doc.patient_id = None
    if "doc_type" in fields and fields["doc_type"] is not None:
        doc.doc_type = fields["doc_type"]
    if "status" in fields and fields["status"] is not None:
        doc.status = fields["status"]

    await db.flush()
    await db.refresh(doc)
    return doc


@router.post("/documents/{doc_id}/assign")
async def assign_document_to_patient(
    doc_id: UUID,
    patient_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    doc = await _get_accessible_document(doc_id, current_user, db)
    patient = await get_scoped_patient(patient_id, current_user, db)
    doc.patient_id = patient.id
    await db.flush()
    return {"assigned": True}
