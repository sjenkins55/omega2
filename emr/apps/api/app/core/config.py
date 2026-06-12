import secrets
import logging
from pydantic_settings import BaseSettings
from pydantic import model_validator
from functools import lru_cache

logger = logging.getLogger(__name__)

_INSECURE_KEY = "change-me-in-production"


class Settings(BaseSettings):
    app_name: str = "ConcertoCare EMR"
    app_version: str = "0.1.0"
    debug: bool = False
    environment: str = "development"  # "development" | "staging" | "production"

    database_url: str = "postgresql+asyncpg://emr:emr@localhost:5432/emr"
    redis_url: str = "redis://localhost:6379/0"

    secret_key: str = _INSECURE_KEY
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480
    portal_token_expire_minutes: int = 60 * 24  # 24 hours (was 7 days)

    # ADT inbound API key — hospitals must pass X-ADT-Key header
    adt_api_key: str = ""

    # AI — set AI_PROVIDER=bedrock to route through AWS Bedrock instead of direct Anthropic
    ai_provider: str = "anthropic"  # "anthropic" | "bedrock"
    anthropic_api_key: str = ""
    ai_model: str = "claude-sonnet-4-6"
    ai_model_opus: str = "claude-opus-4-7"

    # Bedrock model IDs (cross-region inference profiles recommended)
    bedrock_model_id: str = "us.anthropic.claude-sonnet-4-5-20251001-v1:0"
    bedrock_model_id_opus: str = "us.anthropic.claude-3-opus-20240229-v1:0"
    bedrock_guardrails_id: str = ""
    bedrock_guardrails_version: str = "DRAFT"

    # AWS — shared by S3, HealthLake, Bedrock, Comprehend Medical
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_session_token: str = ""
    aws_region: str = "us-east-1"

    s3_bucket: str = "concertocare-emr-docs"

    healthlake_datastore_id: str = ""
    healthlake_endpoint: str = ""

    use_comprehend_medical: bool = False

    # Azure AD / Microsoft SSO
    azure_client_id: str = ""
    azure_tenant_id: str = "common"

    # Fax ingestion
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    fax_inbox_number: str = ""

    cors_origins: list[str] = ["http://localhost:3000"]

    @model_validator(mode="after")
    def check_secret_key(self) -> "Settings":
        if self.secret_key == _INSECURE_KEY:
            if self.environment == "production":
                raise ValueError(
                    "SECRET_KEY must be set to a secure random value in production. "
                    "Generate one with: python -c \"import secrets; print(secrets.token_hex(32))\""
                )
            logger.warning(
                "SECURITY WARNING: Using default SECRET_KEY. "
                "Set SECRET_KEY env var before going to production. "
                "Generate: python -c \"import secrets; print(secrets.token_hex(32))\""
            )
        return self

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
