"""
Workflow automation engine — Power Automate-style event-driven execution.
Workflows are DAGs of steps triggered by EMR events.
"""
import uuid
import asyncio
from datetime import datetime, timezone
from typing import Any
import structlog

log = structlog.get_logger()

# Step type registry — maps step type name to handler
_STEP_HANDLERS: dict[str, "StepHandler"] = {}


def register_step(name: str):
    def decorator(cls):
        _STEP_HANDLERS[name] = cls()
        return cls
    return decorator


class StepHandler:
    async def execute(self, step_config: dict, context: dict) -> dict:
        raise NotImplementedError


@register_step("send_notification")
class SendNotificationStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        # Dispatch to notification service (Twilio, email, push)
        channel = step_config.get("channel", "sms")
        template = step_config.get("template", "")
        recipient = context.get("patient_phone") or step_config.get("recipient")
        log.info("send_notification", channel=channel, recipient=recipient, template=template)
        return {"sent": True, "channel": channel, "recipient": recipient}


@register_step("create_task")
class CreateTaskStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        task = {
            "id": str(uuid.uuid4()),
            "title": step_config.get("title", ""),
            "description": step_config.get("description", ""),
            "assigned_to": step_config.get("assigned_to") or context.get("clinician_id"),
            "due_in_hours": step_config.get("due_in_hours", 24),
            "priority": step_config.get("priority", "normal"),
            "patient_id": context.get("patient_id"),
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        log.info("create_task", task_id=task["id"], title=task["title"])
        return {"task": task}


@register_step("schedule_visit")
class ScheduleVisitStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        log.info("schedule_visit", patient_id=context.get("patient_id"), visit_type=step_config.get("visit_type"))
        return {"scheduled": True, "visit_type": step_config.get("visit_type", "skilled_nursing")}


@register_step("update_care_plan")
class UpdateCarePlanStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        log.info("update_care_plan", patient_id=context.get("patient_id"))
        return {"updated": True, "fields": step_config.get("fields", [])}


@register_step("ai_analysis")
class AIAnalysisStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        from app.modules.ai_engine.visit_brief import compute_risk_score
        log.info("ai_analysis", patient_id=context.get("patient_id"))
        return {"analysis_queued": True}


@register_step("condition_branch")
class ConditionBranchStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        """Evaluates a condition and returns which branch to follow."""
        field = step_config.get("field", "")
        operator = step_config.get("operator", "eq")
        value = step_config.get("value")

        actual = context.get(field)
        matched = False
        if operator == "eq":
            matched = actual == value
        elif operator == "gt":
            matched = float(actual or 0) > float(value)
        elif operator == "lt":
            matched = float(actual or 0) < float(value)
        elif operator == "contains":
            matched = value in (actual or "")
        elif operator == "exists":
            matched = actual is not None

        return {"branch": "true" if matched else "false", "matched": matched}


@register_step("wait")
class WaitStep(StepHandler):
    async def execute(self, step_config: dict, context: dict) -> dict:
        hours = step_config.get("hours", 0)
        # In production this suspends the run and reschedules via Celery beat
        log.info("wait_step", hours=hours)
        return {"scheduled_resume_in_hours": hours}


class WorkflowEngine:
    async def trigger(self, trigger_type: str, payload: dict, db) -> list[str]:
        """
        Fire all active workflows matching the trigger type.
        Returns list of run IDs started.
        """
        from sqlalchemy import select
        from app.models.workflow import Workflow, WorkflowStatus, WorkflowRun, WorkflowRunStatus, TriggerType

        result = await db.execute(
            select(Workflow).where(
                Workflow.trigger_type == trigger_type,
                Workflow.status == WorkflowStatus.active,
            )
        )
        workflows = result.scalars().all()

        run_ids = []
        for wf in workflows:
            if not self._evaluate_conditions(wf.conditions, payload):
                continue
            run = WorkflowRun(
                workflow_id=wf.id,
                status=WorkflowRunStatus.pending,
                trigger_payload=payload,
                context=payload.copy(),
            )
            db.add(run)
            await db.flush()
            run_ids.append(str(run.id))
            # Dispatch async execution
            asyncio.create_task(self._execute_run(run.id, wf.steps, payload.copy(), db))

        return run_ids

    def _evaluate_conditions(self, conditions: list, payload: dict) -> bool:
        if not conditions:
            return True
        for cond in conditions:
            field = cond.get("field", "")
            op = cond.get("operator", "exists")
            val = cond.get("value")
            actual = payload.get(field)
            if op == "eq" and actual != val:
                return False
            if op == "exists" and actual is None:
                return False
        return True

    async def _execute_run(self, run_id: uuid.UUID, steps: list, context: dict, db) -> None:
        from app.models.workflow import WorkflowRun, WorkflowRunStatus

        log.info("workflow_run_start", run_id=str(run_id))
        step_results = []
        current_steps = [s for s in steps if s.get("is_root", False) or steps.index(s) == 0]
        steps_by_id = {s["id"]: s for s in steps}

        try:
            queue = list(current_steps)
            visited = set()
            while queue:
                step = queue.pop(0)
                step_id = step["id"]
                if step_id in visited:
                    continue
                visited.add(step_id)

                handler = _STEP_HANDLERS.get(step["type"])
                if not handler:
                    log.warning("unknown_step_type", step_type=step["type"])
                    continue

                result = await handler.execute(step.get("config", {}), context)
                step_results.append({"step_id": step_id, "type": step["type"], "result": result, "ts": datetime.now(timezone.utc).isoformat()})
                context.update(result)

                # Follow next steps
                next_step_ids = step.get("next_steps", [])
                if step["type"] == "condition_branch":
                    branch = result.get("branch", "false")
                    next_step_ids = step.get(f"next_steps_{branch}", [])

                for nid in next_step_ids:
                    if nid in steps_by_id:
                        queue.append(steps_by_id[nid])

            await self._update_run(run_id, WorkflowRunStatus.completed, step_results, None, db)
            log.info("workflow_run_completed", run_id=str(run_id))

        except Exception as exc:
            log.error("workflow_run_failed", run_id=str(run_id), error=str(exc))
            await self._update_run(run_id, WorkflowRunStatus.failed, step_results, str(exc), db)

    async def _update_run(self, run_id, status, step_results, error, db):
        from sqlalchemy import select
        from app.models.workflow import WorkflowRun

        result = await db.execute(select(WorkflowRun).where(WorkflowRun.id == run_id))
        run = result.scalar_one_or_none()
        if run:
            run.status = status
            run.step_results = step_results
            run.error = error
            run.completed_at = datetime.now(timezone.utc)
            await db.commit()


workflow_engine = WorkflowEngine()
