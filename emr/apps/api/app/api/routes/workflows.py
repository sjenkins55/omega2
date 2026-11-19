from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from app.db.base import get_db
from app.models.workflow import Workflow, WorkflowRun, WorkflowStatus
from app.schemas.workflow import WorkflowCreate, WorkflowUpdate, WorkflowResponse

router = APIRouter(prefix="/workflows", tags=["workflows"])


@router.get("", response_model=list[WorkflowResponse])
async def list_workflows(
    status: WorkflowStatus | None = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(Workflow)
    if status:
        query = query.where(Workflow.status == status)
    result = await db.execute(query.order_by(Workflow.name))
    return result.scalars().all()


@router.get("/{workflow_id}", response_model=WorkflowResponse)
async def get_workflow(workflow_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Workflow).where(Workflow.id == workflow_id))
    wf = result.scalar_one_or_none()
    if not wf:
        raise HTTPException(404, "Workflow not found")
    return wf


@router.post("", response_model=WorkflowResponse, status_code=201)
async def create_workflow(body: WorkflowCreate, db: AsyncSession = Depends(get_db)):
    wf = Workflow(**body.model_dump())
    db.add(wf)
    await db.flush()
    await db.refresh(wf)
    return wf


@router.patch("/{workflow_id}", response_model=WorkflowResponse)
async def update_workflow(workflow_id: UUID, body: WorkflowUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Workflow).where(Workflow.id == workflow_id))
    wf = result.scalar_one_or_none()
    if not wf:
        raise HTTPException(404, "Workflow not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(wf, field, value)
    await db.flush()
    await db.refresh(wf)
    return wf


@router.post("/{workflow_id}/activate")
async def activate_workflow(workflow_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Workflow).where(Workflow.id == workflow_id))
    wf = result.scalar_one_or_none()
    if not wf:
        raise HTTPException(404, "Workflow not found")
    wf.status = WorkflowStatus.active
    await db.flush()
    return {"activated": True}


@router.post("/{workflow_id}/test-run")
async def test_run_workflow(workflow_id: UUID, payload: dict, db: AsyncSession = Depends(get_db)):
    """Fire a workflow manually with a test payload."""
    from app.modules.workflows.engine import workflow_engine
    result = await db.execute(select(Workflow).where(Workflow.id == workflow_id))
    wf = result.scalar_one_or_none()
    if not wf:
        raise HTTPException(404, "Workflow not found")
    # Temporarily activate for test
    original_status = wf.status
    wf.status = WorkflowStatus.active
    run_ids = await workflow_engine.trigger(wf.trigger_type, payload, db)
    wf.status = original_status
    await db.flush()
    return {"run_ids": run_ids}


@router.get("/{workflow_id}/runs")
async def list_workflow_runs(workflow_id: UUID, limit: int = 50, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(WorkflowRun)
        .where(WorkflowRun.workflow_id == workflow_id)
        .order_by(WorkflowRun.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/step-types/catalog")
async def get_step_type_catalog():
    """Return all available workflow step types for the builder UI."""
    from app.modules.workflows.engine import _STEP_HANDLERS
    return {
        "step_types": [
            {
                "type": "send_notification",
                "label": "Send Notification",
                "description": "Send SMS, email, or push notification to patient or staff",
                "config_schema": {"channel": "sms|email|push", "template": "string", "recipient": "string"},
                "category": "communication",
            },
            {
                "type": "create_task",
                "label": "Create Task",
                "description": "Create a task and assign it to a clinician or team",
                "config_schema": {"title": "string", "description": "string", "assigned_to": "user_id", "due_in_hours": "int", "priority": "urgent|high|normal"},
                "category": "task",
            },
            {
                "type": "schedule_visit",
                "label": "Schedule Visit",
                "description": "Automatically schedule a follow-up visit",
                "config_schema": {"visit_type": "string", "days_from_now": "int"},
                "category": "care",
            },
            {
                "type": "update_care_plan",
                "label": "Update Care Plan",
                "description": "Update specific fields in the patient care plan",
                "config_schema": {"fields": "array"},
                "category": "care",
            },
            {
                "type": "ai_analysis",
                "label": "AI Analysis",
                "description": "Trigger AI risk re-stratification for the patient",
                "config_schema": {},
                "category": "ai",
            },
            {
                "type": "condition_branch",
                "label": "Condition / Branch",
                "description": "Branch workflow based on a field value",
                "config_schema": {"field": "string", "operator": "eq|gt|lt|contains|exists", "value": "any"},
                "category": "logic",
            },
            {
                "type": "wait",
                "label": "Wait",
                "description": "Pause workflow execution for N hours before continuing",
                "config_schema": {"hours": "int"},
                "category": "logic",
            },
        ]
    }
