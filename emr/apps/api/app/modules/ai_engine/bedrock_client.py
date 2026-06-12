"""
AWS Bedrock client for Claude.
Wraps boto3 bedrock-runtime converse() and normalises the response
to match the Anthropic SDK shape so agent_loop.py needs zero changes.

Bedrock Converse API docs:
https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Converse.html
"""
from __future__ import annotations
import json
import asyncio
from typing import Any
import boto3
import structlog
from app.core.config import get_settings

log = structlog.get_logger()
settings = get_settings()


# ── Normalised response objects (Anthropic-compatible duck types) ──────────

class _TextBlock:
    type = "text"
    def __init__(self, text: str):
        self.text = text

class _ToolUseBlock:
    type = "tool_use"
    def __init__(self, tool_use_id: str, name: str, input: dict):
        self.id = tool_use_id
        self.name = name
        self.input = input

class _BedrockResponse:
    """Normalised response that looks like anthropic.types.Message."""
    def __init__(self, stop_reason: str, content: list):
        self.stop_reason = stop_reason
        self.content = content


def _boto_session() -> boto3.Session:
    kwargs: dict[str, str] = {"region_name": settings.aws_region}
    if settings.aws_access_key_id:
        kwargs["aws_access_key_id"] = settings.aws_access_key_id
        kwargs["aws_secret_access_key"] = settings.aws_secret_access_key
    if settings.aws_session_token:
        kwargs["aws_session_token"] = settings.aws_session_token
    return boto3.Session(**kwargs)


def _anthropic_tools_to_bedrock(tools: list[dict]) -> list[dict]:
    """Convert Anthropic tool format → Bedrock toolSpec format."""
    return [
        {
            "toolSpec": {
                "name": t["name"],
                "description": t.get("description", ""),
                "inputSchema": {"json": t.get("input_schema", {"type": "object", "properties": {}})},
            }
        }
        for t in tools
    ]


def _anthropic_messages_to_bedrock(messages: list[dict]) -> list[dict]:
    """
    Convert Anthropic messages (which may contain tool_use / tool_result blocks
    as Anthropic SDK objects or plain dicts) → Bedrock Converse format.
    """
    bedrock_messages = []
    for msg in messages:
        role = msg["role"]
        raw_content = msg["content"]

        if isinstance(raw_content, str):
            bedrock_messages.append({"role": role, "content": [{"text": raw_content}]})
            continue

        blocks = []
        for block in raw_content:
            # Handle Anthropic SDK objects (from prior assistant turns)
            if hasattr(block, "type"):
                if block.type == "text":
                    blocks.append({"text": block.text})
                elif block.type == "tool_use":
                    blocks.append({
                        "toolUse": {
                            "toolUseId": block.id,
                            "name": block.name,
                            "input": block.input,
                        }
                    })
            # Handle plain dicts (tool_result from user turns)
            elif isinstance(block, dict):
                if block.get("type") == "tool_result":
                    blocks.append({
                        "toolResult": {
                            "toolUseId": block["tool_use_id"],
                            "content": [{"text": block.get("content", "")}],
                            "status": "success",
                        }
                    })
                elif block.get("type") == "text":
                    blocks.append({"text": block["text"]})
                elif "text" in block:
                    blocks.append({"text": block["text"]})

        if blocks:
            bedrock_messages.append({"role": role, "content": blocks})

    return bedrock_messages


def _bedrock_response_to_anthropic(response: dict) -> _BedrockResponse:
    """Convert Bedrock Converse response → Anthropic-compatible response."""
    stop_reason_map = {
        "end_turn": "end_turn",
        "tool_use": "tool_use",
        "max_tokens": "max_tokens",
        "stop_sequence": "stop_sequence",
        "guardrail_intervened": "end_turn",
    }
    stop_reason = stop_reason_map.get(response.get("stopReason", "end_turn"), "end_turn")

    raw_content = response.get("output", {}).get("message", {}).get("content", [])
    content = []
    for block in raw_content:
        if "text" in block:
            content.append(_TextBlock(block["text"]))
        elif "toolUse" in block:
            tu = block["toolUse"]
            content.append(_ToolUseBlock(
                tool_use_id=tu["toolUseId"],
                name=tu["name"],
                input=tu.get("input", {}),
            ))

    return _BedrockResponse(stop_reason=stop_reason, content=content)


class BedrockMessagesClient:
    """
    Drop-in replacement for anthropic.AsyncAnthropic that routes through
    AWS Bedrock. Exposes the same `.messages.create()` interface.
    """

    def __init__(self):
        self._session = _boto_session()
        self._runtime = self._session.client("bedrock-runtime")

    class _Messages:
        def __init__(self, runtime, guardrails_id: str, guardrails_version: str):
            self._runtime = runtime
            self._guardrails_id = guardrails_id
            self._guardrails_version = guardrails_version

        async def create(
            self,
            model: str,
            max_tokens: int,
            system: str,
            tools: list[dict] | None = None,
            messages: list[dict] | None = None,
            **kwargs,
        ) -> _BedrockResponse:
            bedrock_model_id = _map_model_id(model)
            bedrock_messages = _anthropic_messages_to_bedrock(messages or [])

            request: dict[str, Any] = {
                "modelId": bedrock_model_id,
                "messages": bedrock_messages,
                "system": [{"text": system}],
                "inferenceConfig": {"maxTokens": max_tokens, "temperature": 0.0},
            }

            if tools:
                request["toolConfig"] = {"tools": _anthropic_tools_to_bedrock(tools)}

            if self._guardrails_id:
                request["guardrailConfig"] = {
                    "guardrailIdentifier": self._guardrails_id,
                    "guardrailVersion": self._guardrails_version,
                    "trace": "enabled",
                }

            log.info("bedrock_converse", model=bedrock_model_id, message_count=len(bedrock_messages))

            # boto3 is synchronous — run in thread pool
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self._runtime.converse(**request),
            )

            if self._guardrails_id and response.get("trace", {}).get("guardrail", {}).get("inputAssessment"):
                log.info("bedrock_guardrail_trace", trace=response["trace"]["guardrail"])

            return _bedrock_response_to_anthropic(response)

    @property
    def messages(self):
        return self._Messages(
            self._runtime,
            settings.bedrock_guardrails_id,
            settings.bedrock_guardrails_version,
        )


def _map_model_id(anthropic_model: str) -> str:
    """Map a friendly model name to a Bedrock cross-region inference profile ID."""
    mapping = {
        "claude-sonnet-4-6":           settings.bedrock_model_id,
        "claude-opus-4-7":             settings.bedrock_model_id_opus,
        # Pass-through if it's already a full Bedrock ID
    }
    return mapping.get(anthropic_model, anthropic_model)
