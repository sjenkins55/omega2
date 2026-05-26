"""
ReAct-style agent loop using Claude's native tool_use API.
Replaces one-shot prompting with iterative FHIR tool calls.

Pattern (from MedAgentBench):
  1. Claude receives task + available tools
  2. Claude calls tools as needed (up to MAX_ROUNDS)
  3. Tool results injected back as user messages
  4. Claude produces final structured output on stop_reason == "end_turn"
  5. Hard cap at MAX_ROUNDS forces completion even if agent loops
"""
import json
from typing import Any
import anthropic
import structlog

from app.modules.ai_engine.client import get_ai_client
from app.modules.ai_engine.fhir_tools import FHIR_TOOLS
from app.modules.ai_engine.fhir_executor import execute_tool
from app.core.config import get_settings

log = structlog.get_logger()
settings = get_settings()

MAX_ROUNDS = 8

SYSTEM_PROMPT = """\
You are a clinical AI assistant embedded in a home care EMR for ConcertoCare.
You have access to FHIR tools to query and update the patient's electronic health record.
Be clinically precise. Never fabricate lab values, medications, or diagnoses.
If data is missing or ambiguous, state that clearly rather than guessing.
Always prefer retrieving fresh data over relying on memory."""


async def run_agent(
    task_prompt: str,
    patient_id: str,
    db,
    model: str | None = None,
    extra_tools: list[dict] | None = None,
    max_rounds: int = MAX_ROUNDS,
) -> dict:
    """
    Run the clinical agent loop for a given task.

    Returns:
        {
          "result": <final text output from Claude>,
          "tool_calls": [list of tool calls made],
          "rounds": int,
          "model": str,
        }
    """
    client = get_ai_client()
    model = model or settings.ai_model
    tools = FHIR_TOOLS + (extra_tools or [])

    messages: list[dict] = [{"role": "user", "content": task_prompt}]
    tool_call_log: list[dict] = []
    round_num = 0

    log.info("agent_loop_start", patient_id=patient_id, model=model)

    while round_num < max_rounds:
        round_num += 1

        response = await client.messages.create(
            model=model,
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=tools,
            messages=messages,
        )

        log.info("agent_loop_round", round=round_num, stop_reason=response.stop_reason)

        # Append assistant turn
        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            # Extract final text
            final_text = _extract_text(response.content)
            log.info("agent_loop_done", rounds=round_num, patient_id=patient_id)
            return {
                "result": final_text,
                "tool_calls": tool_call_log,
                "rounds": round_num,
                "model": model,
            }

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    log.info("tool_call", tool=block.name, input=block.input)
                    result = await execute_tool(block.name, block.input, db, patient_id)
                    tool_call_log.append({
                        "round": round_num,
                        "tool": block.name,
                        "input": block.input,
                        "result": result,
                    })
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result, default=str),
                    })
            messages.append({"role": "user", "content": tool_results})
            continue

        # Unexpected stop reason — break and return what we have
        log.warning("agent_loop_unexpected_stop", stop_reason=response.stop_reason)
        break

    # Max rounds hit — force a final summary from the last assistant message
    log.warning("agent_loop_max_rounds", rounds=round_num, patient_id=patient_id)
    last_text = _extract_text(messages[-1].get("content", []) if isinstance(messages[-1].get("content"), list) else [])
    if not last_text:
        # Ask Claude to wrap up with what it has
        messages.append({"role": "user", "content": "You have reached the maximum number of tool calls. Summarize your findings and provide your final answer now."})
        final_response = await client.messages.create(
            model=model,
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=messages,
        )
        last_text = _extract_text(final_response.content)

    return {
        "result": last_text,
        "tool_calls": tool_call_log,
        "rounds": round_num,
        "model": model,
        "warning": "max_rounds_reached",
    }


def _extract_text(content: list | str) -> str:
    if isinstance(content, str):
        return content
    parts = []
    for block in content:
        if hasattr(block, "type") and block.type == "text":
            parts.append(block.text)
        elif isinstance(block, dict) and block.get("type") == "text":
            parts.append(block["text"])
    return "\n".join(parts).strip()
