"""Celery background tasks for document ingestion pipeline."""
from celery import Celery
from app.core.config import get_settings

settings = get_settings()
celery_app = Celery("emr", broker=settings.redis_url, backend=settings.redis_url)


@celery_app.task(bind=True, max_retries=3)
def process_document_task(self, document_id: str, source_url: str | None = None):
    """
    Full document processing pipeline:
    1. Download from S3 or URL
    2. OCR if PDF/image
    3. AI classification + extraction
    4. Patient matching
    5. Trigger workflows
    """
    import asyncio
    asyncio.run(_process_document(document_id, source_url))


async def _process_document(document_id: str, source_url: str | None):
    import httpx
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
    from app.db.base import Base
    from app.models.document import Document, DocumentStatus
    from app.modules.ingestion.fax_processor import classify_and_extract_document, match_patient_from_document
    from app.modules.workflows.engine import workflow_engine
    from sqlalchemy import select

    engine = create_async_engine(settings.database_url)
    Session = async_sessionmaker(engine)

    async with Session() as db:
        result = await db.execute(select(Document).where(Document.id == document_id))
        doc = result.scalar_one_or_none()
        if not doc:
            return

        doc.status = DocumentStatus.processing
        await db.commit()

        try:
            # Get raw text — download and OCR if needed
            raw_text = ""
            if source_url:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(source_url)
                    content = resp.content
                    raw_text = _ocr_content(content, doc.mime_type)
            elif doc.s3_key:
                import boto3
                s3 = boto3.client("s3")
                obj = s3.get_object(Bucket=settings.s3_bucket, Key=doc.s3_key)
                content = obj["Body"].read()
                raw_text = _ocr_content(content, doc.mime_type)

            doc.raw_text = raw_text
            extracted = await classify_and_extract_document(raw_text, doc.file_name)
            doc.extracted_data = extracted
            doc.doc_type = extracted.get("document_type", "other")
            doc.ai_summary = extracted.get("clinical_summary", "")
            doc.requires_action = extracted.get("requires_action", False)

            patient_id = await match_patient_from_document(extracted, db)
            if patient_id:
                doc.patient_id = patient_id

            doc.status = DocumentStatus.indexed
            from datetime import datetime, timezone
            doc.processed_at = datetime.now(timezone.utc)

            # Trigger workflows
            for trigger_name in extracted.get("suggested_workflow_triggers", []):
                await workflow_engine.trigger("document_received", {
                    "document_id": document_id,
                    "document_type": doc.doc_type,
                    "patient_id": patient_id,
                    "trigger_name": trigger_name,
                }, db)

            await db.commit()

        except Exception as exc:
            doc.status = DocumentStatus.failed
            await db.commit()
            raise


def _ocr_content(content: bytes, mime_type: str) -> str:
    """OCR PDF or image content to text."""
    if "pdf" in (mime_type or ""):
        try:
            import PyPDF2
            import io
            reader = PyPDF2.PdfReader(io.BytesIO(content))
            return "\n".join(page.extract_text() or "" for page in reader.pages)
        except Exception:
            pass
    if any(t in (mime_type or "") for t in ["image", "tiff", "jpeg", "png"]):
        try:
            import pytesseract
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(content))
            return pytesseract.image_to_string(img)
        except Exception:
            pass
    try:
        return content.decode("utf-8", errors="replace")
    except Exception:
        return ""
