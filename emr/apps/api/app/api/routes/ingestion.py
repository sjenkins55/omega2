from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
import io
from app.db.base import get_db
from app.models.document import Document, DocumentStatus

router = APIRouter(prefix="/ingestion", tags=["ingestion"])


@router.post("/fax/webhook")
async def receive_fax_webhook(
    fax_sid: str = Form(...),
    from_number: str = Form(...),
    to_number: str = Form(...),
    media_url: str = Form(...),
    num_pages: int = Form(1),
    db: AsyncSession = Depends(get_db),
):
    """
    Twilio Fax webhook — creates a Document record and queues processing.
    """
    doc = Document(
        doc_type="fax",
        status=DocumentStatus.received,
        source="twilio_fax",
        source_fax_number=from_number,
        file_name=f"fax_{fax_sid}.pdf",
        s3_key=f"faxes/{fax_sid}.pdf",
        mime_type="application/pdf",
        page_count=num_pages,
    )
    db.add(doc)
    await db.flush()
    await db.refresh(doc)

    # Queue background processing
    from app.modules.ingestion.tasks import process_document_task
    process_document_task.delay(str(doc.id), media_url)

    return {"received": True, "document_id": str(doc.id)}


@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    patient_id: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
):
    """Manual document upload — staff can upload PDFs, images, etc."""
    import boto3
    from app.core.config import get_settings
    settings = get_settings()

    content = await file.read()
    s3_key = f"uploads/{file.filename}"

    s3 = boto3.client(
        "s3",
        aws_access_key_id=settings.aws_access_key_id,
        aws_secret_access_key=settings.aws_secret_access_key,
        region_name=settings.aws_region,
    )
    s3.put_object(Bucket=settings.s3_bucket, Key=s3_key, Body=content, ContentType=file.content_type)

    doc = Document(
        patient_id=UUID(patient_id) if patient_id else None,
        doc_type="other",
        status=DocumentStatus.received,
        source="manual_upload",
        file_name=file.filename,
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
):
    query = select(Document)
    if patient_id:
        query = query.where(Document.patient_id == patient_id)
    if status:
        query = query.where(Document.status == status)
    result = await db.execute(query.order_by(Document.received_at.desc()).limit(limit))
    return result.scalars().all()


@router.get("/documents/{doc_id}")
async def get_document(doc_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Document not found")
    return doc


@router.post("/documents/{doc_id}/assign")
async def assign_document_to_patient(doc_id: UUID, patient_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Document).where(Document.id == doc_id))
    doc = result.scalar_one_or_none()
    if not doc:
        raise HTTPException(404, "Document not found")
    doc.patient_id = patient_id
    await db.flush()
    return {"assigned": True}
