"""
AI client factory.
Set AI_PROVIDER=bedrock in .env to route through AWS Bedrock (HIPAA BAA + Guardrails).
Default is direct Anthropic API.
"""
import anthropic
from app.core.config import get_settings

settings = get_settings()

_anthropic_client: anthropic.AsyncAnthropic | None = None
_bedrock_client = None


def get_ai_client():
    """Return the configured AI client (Anthropic or Bedrock). Thread-safe singleton."""
    if settings.ai_provider == "bedrock":
        return _get_bedrock_client()
    return _get_anthropic_client()


def _get_anthropic_client() -> anthropic.AsyncAnthropic:
    global _anthropic_client
    if _anthropic_client is None:
        _anthropic_client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    return _anthropic_client


def _get_bedrock_client():
    global _bedrock_client
    if _bedrock_client is None:
        from app.modules.ai_engine.bedrock_client import BedrockMessagesClient
        _bedrock_client = BedrockMessagesClient()
    return _bedrock_client
